#pragma OPENCL EXTENSION cl_khr_fp64 : enable

__kernel void generalized_volm_obj_based_matching_with_orient(__global unsigned*                 n_cam,         // query -- number of cameras (single unsigned)
                                                              __global unsigned*                 n_obj,         // query -- number of objects (single unsigned)
                                                              __global unsigned*                grd_id,         // query -- ground index id
                                                              __global unsigned*            grd_offset,         // query -- ground array offset indicator
                                                              __global unsigned char*         grd_dist,         // query -- ground query distance   (single float)
                                                              __global float*               grd_weight,         // query -- ground weight parameter (single float)
                                                              __global float*            grd_wgt_attri,         // query -- ground weight parameters for different attributes (3 floats)
                                                              __global unsigned*                sky_id,         // query -- sky index id
                                                              __global unsigned*            sky_offset,         // query -- sky array offset indicator
                                                              __global float*               sky_weight,         // query -- sky weight parameter
                                                              __global unsigned*                obj_id,         // query -- object index id
                                                              __global unsigned*            obj_offset,         // query -- object array offset indicator
                                                              __global unsigned char*     obj_min_dist,         // query -- object query minimium distance
                                                              __global unsigned char*       obj_orient,         // query -- object query orientation
                                                              __global float*               obj_weight,         // query -- object weight parameter array (n_obj floats)
                                                              __global float*            obj_wgt_attri,         // query -- object wieght parameter array (4*n_obj floats)
                                                              __global unsigned*                 n_ind,         // index -- number of indices passed into device (single unsigned)
                                                              __global unsigned*            layer_size,         // index -- size of spherical shell container (single unsigned)
                                                              __global unsigned char*            index,         // index -- index depth array
                                                              __global unsigned char*     index_orient,         // index -- index orientation array (0,100 invalid, 1 -- horizontal, 2 - 9 vertical, 254 -- sky)
                                                              __global float*                    score,         // score array (score per index per camera)
                                                              __global float*                       mu,         // average depth array for index
                                                              __global float*           depth_interval,         // depth_interval
                                                              __global unsigned*          depth_length,         // length of depth_interval table
                                                              __global float*                    debug,         // debug array
                                                              __local unsigned char*    local_min_dist,         // query -- object minimimu distance on local memory
                                                              __local unsigned char*  local_obj_orient,         // query -- object orientation on local memory
                                                              __local float*          local_obj_weight,         // query -- object weight parameters on local memory
                                                              __local float*       local_obj_wgt_attri,         // query -- object weight parameters (for attributes) on local memory
                                                              __local float*       local_grd_wgt_attri,         // query -- object wieght parameters (for attributes) on local memory
                                                              __local float*      local_depth_interval)         // depth_interval on local memory
{
  // get the cam_id and ind_id
  unsigned cam_id = 0, ind_id = 0;
  ind_id = get_global_id(0);
  cam_id = get_global_id(1);
  unsigned llid = (get_local_id(0) + get_local_size(0)*get_local_id(1));

  //bool debug_bool = (ind_id == 143) && (cam_id == 3);

  // passing necessary values from global to the local memory
  __local unsigned ln_cam, ln_obj, ln_ind, ln_layer_size, ln_depth_size;
  __local float l_grd_weight, l_sky_weight;

  if (llid == 0) {
    ln_cam = *n_cam;
    ln_obj = *n_obj;
    ln_ind = *n_ind;
    ln_layer_size = *layer_size;
    l_grd_weight = *grd_weight;
    l_sky_weight = *sky_weight;
    ln_depth_size = *depth_length;
  }
  if (llid < *n_obj) {
    local_min_dist[llid] = obj_min_dist[llid];
    local_obj_orient[llid] = obj_orient[llid];
    local_obj_weight[llid] = obj_weight[llid];
  }
  barrier(CLK_LOCAL_MEM_FENCE);

  // doing this copy using only one work item because the size of depth_interval can be larger than than the work group size...
  if (llid == 0) {
    for (unsigned di = 0; di < ln_depth_size; di++)
      local_depth_interval[di] = depth_interval[di];
  }
  barrier(CLK_LOCAL_MEM_FENCE);

  if (llid < ln_obj*4) {
    local_obj_wgt_attri[llid] = obj_wgt_attri[llid];
  }
  barrier(CLK_LOCAL_MEM_FENCE);

  if (llid < 3) {
    local_grd_wgt_attri[llid] = grd_wgt_attri[llid];
  }
  barrier(CLK_LOCAL_MEM_FENCE);

  // Start the matcher
  if ( cam_id < ln_cam && ind_id < ln_ind ) {
    // locate index offset
    unsigned start_ind = ind_id * (ln_layer_size);
    // calculate sky score
    // locate the sky array
    unsigned start_sky = sky_offset[cam_id];
    unsigned end_sky = sky_offset[cam_id+1];
    unsigned sky_count = 0;
    for (unsigned k = start_sky; k < end_sky; ++k) {
      unsigned id = start_ind + sky_id[k];
      if ( index[id] == 254 )
        sky_count += 1;
    }
    float score_sky;
    score_sky = (end_sky != start_sky) ? (float)sky_count/(end_sky-start_sky) : 0;
    score_sky = score_sky * l_sky_weight;

    // calculate ground score
    // define the altitude ratio, suppose the altitude in index could ba up to 3 meter
    // assuming the read-in alt values in query is normally ~1m, the altiutide ratio would be (2-1)/1 ~2
    // the altitude ratio defined the tolerance for ground distance d as delta_d = alt_ratio * d
    unsigned char alt_ratio = 2;
    unsigned start_grd = grd_offset[cam_id];
    unsigned end_grd = grd_offset[cam_id+1];
    unsigned grd_count = 0;
    unsigned grd_count_ori = 0;
    for (unsigned k = start_grd; k < end_grd; ++k) {
      unsigned id = start_ind + grd_id[k];
      if (index[id] < ln_depth_size && grd_dist[k] < ln_depth_size ) {
        float ind_d = local_depth_interval[index[id]];
        float grd_d = local_depth_interval[grd_dist[k]];
        float delta_d = alt_ratio * grd_d;
        if ( ind_d >= (grd_d - delta_d) && ind_d <= (grd_d+delta_d) )
          grd_count += 1;
      }
      if (index_orient[id] == 1) // ground should always be horizontal
       grd_count_ori += 1;
    }
    float score_grd;
    score_grd = (float)(local_grd_wgt_attri[2] * grd_count + local_grd_wgt_attri[0] * grd_count_ori); // ground score is composed by distance and orientation
    score_grd = (end_grd != start_grd) ? score_grd / (end_grd-start_grd) : 0;
    score_grd = score_grd * l_grd_weight;

    // calculate object score
    // calcualte average mean depth value first
    // locate the mu index to store the mean value
    unsigned mu_start_id = cam_id*ln_obj + ind_id*ln_cam*ln_obj;
    for (unsigned k = 0; k < ln_obj; ++k) {              // loop over each object for cam_id and ind_id
      unsigned offset_id = k + ln_obj * cam_id;
      unsigned start_obj = obj_offset[offset_id];
      unsigned end_obj = obj_offset[offset_id+1];
         float mu_obj = 0;
      unsigned count = 0;

      for (unsigned i = start_obj; i < end_obj; ++i) {   // loop over each voxel in object k
        unsigned id = start_ind + obj_id[i];
        unsigned d = index[id];
        if (d < 253 && d < ln_depth_size) {
          mu_obj += local_depth_interval[d];
          count += 1;
        }
      }
      mu_obj = (count > 0) ? mu_obj/count : 0;
      unsigned mu_id = k + mu_start_id;
      mu[mu_id] =  mu_obj;
    }
    // calculate object score
    // note that the two neighboring objects may have same order
    // therefore voxel depth could be less or eqaul the meaning depth of the objects with lower order
    // and could be greater or eqaul the meaning depth of the object with higher order
    float score_obj = 0.0f;
    for (unsigned k = 0; k < ln_obj; ++k) {
      unsigned offset_id = k + ln_obj * cam_id;
      unsigned start_obj = obj_offset[offset_id];
      unsigned end_obj = obj_offset[offset_id+1];
      float score_k_ord = 0.0f;
      float score_k_min = 0.0f;
      float score_k_ori = 0.0f;
      for (unsigned i = start_obj; i < end_obj; ++i) {
        unsigned id = start_ind + obj_id[i];
        unsigned d = index[id];
        unsigned s_vox_ord = 1;
        unsigned s_vox_min = 0;
        unsigned s_vox_ori = 0;
        if (d < 253 && d < ln_depth_size) {
          // calculate order score for voxel i
          for (unsigned mu_id = 0; (s_vox_ord && mu_id < k); ++mu_id)
            if (mu[mu_id+mu_start_id] != 0)
              s_vox_ord = s_vox_ord * (local_depth_interval[d] >= mu[mu_id + mu_start_id]);
          for (unsigned mu_id = k+1; (s_vox_ord && mu_id < ln_obj); ++mu_id)
            if (mu[mu_id+mu_start_id] != 0)
              s_vox_ord = s_vox_ord * (local_depth_interval[d] <= mu[mu_id + mu_start_id]);
          // calculate min_distance socre for voxel i
          s_vox_min = (d > local_min_dist[k]) ? 1 : 0;
        }
        else {
          s_vox_ord = 0;
        }
        // calculate orientation of object
        unsigned char ind_ori = index_orient[id];
        if (ind_ori > 0 && ind_ori < 10) {  // check whether index orientation is meaningful
          s_vox_ori = (ind_ori == local_obj_orient[k]) ? 1 : 0;               // index and query are both horzontal or exactly vertical
          if (!s_vox_ori)
            s_vox_ori = (ind_ori != 1 && local_obj_orient[k] == 2) ? 1 : 0;  // index are non-horizontal and query are vertical
          // we have overlap but ensure the s_vox_ori happens only when
          // ind_ori == 1 and query_ori == 1  ---> all horizontal
          // ind_ori == 2 and query_ori == 2  ---> all exactly vertical (front-parallel)
          // ind_ori == 3-9 and query_ori == 2 --> index is heading to 8 different direction, e.g, southwest, but transfer to vertical
        }
        score_k_ord += (float)s_vox_ord;
        score_k_min += (float)s_vox_min;
        score_k_ori += (float)s_vox_ori;
      }
      // normalized the score for object k
      float score_k = local_obj_wgt_attri[k*4+3]*score_k_ord + local_obj_wgt_attri[k*4+2]*score_k_min + local_obj_wgt_attri[k*4]*score_k_ori;  // object score is composed by relative order, depth, and orientation
      score_k = (end_obj != start_obj) ? score_k/(end_obj-start_obj) : 0;
      score_k *= local_obj_weight[k];
      // summerize the object score
      score_obj += score_k;
    }

#if 0
    if ( cam_id == 3 && ind_id == 8 ) {
       debug[0] = cam_id;
       debug[1] = ind_id;
       debug[2] = local_grd_wgt_attri[0];
       debug[3] = local_grd_wgt_attri[1];
       debug[4] = local_grd_wgt_attri[2];
       debug[5] = l_grd_weight;
       debug[6] = score_sky;
       debug[7] = score_grd;
       debug[8] = score_obj;
    }
#endif

    // summerize the scores
    unsigned score_id = cam_id + ind_id*ln_cam;
    score[score_id] = score_sky + score_grd + score_obj;
  }  // end of the calculation of index ind_id and camera cam_id
}
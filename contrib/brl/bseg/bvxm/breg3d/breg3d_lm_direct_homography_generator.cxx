#include "breg3d_lm_direct_homography_generator.h"

#include <vnl/vnl_double_3x3.h>
#include <vnl/vnl_double_2x3.h>
#include <vil/vil_image_view.h>

#include <vpgl/ihog/ihog_transform_2d.h>
#include <vpgl/ihog/ihog_image.h>
#include <vpgl/ihog/ihog_world_roi.h>
#include <vpgl/ihog/ihog_minimizer.h>

ihog_transform_2d breg3d_lm_direct_homography_generator::compute_homography()
{
  int border = 2;
  ihog_world_roi roi(img0_->ni()- 2*border, img0_->nj()- 2*border,vgl_point_2d<double>(border,border));

  ihog_transform_2d init_xform;
  if (this->compute_projective_) {
    vnl_double_3x3 M; M.set_identity();
    init_xform.set_projective(M);
  }
  else
    init_xform.set_affine(vnl_double_2x3(1,0,0, 0,1,0));

  ihog_minimizer *minimizer = 0;
  // no masks
  if (!use_mask0_ && !use_mask1_) {
    ihog_image<float> from_img(*img0_, init_xform);
    ihog_image<float> to_img(*img1_, ihog_transform_2d());
    minimizer = new ihog_minimizer(from_img, to_img, roi);
  }
  // one mask
  else if (!use_mask0_ || !use_mask1_) {
    ihog_image<float> from_img(*img0_, init_xform);
    ihog_image<float> to_img(*img1_, ihog_transform_2d());
    if (use_mask0_) {
      ihog_image<float> mask_img(*mask0_, init_xform);
      minimizer = new ihog_minimizer(from_img, to_img, mask_img, roi, false);
    }
    else {
      ihog_image<float> mask_img(*mask1_, ihog_transform_2d());
      minimizer = new ihog_minimizer(from_img, to_img, mask_img, roi, true);
    }
  }
  // both masks
  else {
    ihog_image<float> from_img(*img0_, init_xform);
    ihog_image<float> from_mask(*mask0_, init_xform);
    ihog_image<float> to_img(*img1_, ihog_transform_2d());
    ihog_image<float> to_mask(*mask1_, ihog_transform_2d());
    minimizer = new ihog_minimizer(from_img, to_img, from_mask, to_mask, roi);
  }

  vcl_cout << " minimizing image error..";
  minimizer->minimize(init_xform);
  vcl_cout << "..done." << vcl_endl;
  double curr_error = minimizer->get_end_error();
  vcl_cout << "end error = " << curr_error << vcl_endl;
  // computed homography maps pixels in current image to pixels in base image
  //vnl_double_3x3 H = init_xform.get_inverse().get_matrix();
  delete minimizer;
  return init_xform;
}


// This is brl/bseg/bvpl/pro/processes/bvpl_convert_direction_to_hue_process.cxx
#include <bprb/bprb_func_process.h>
//:
// \file
// \brief A process for converting direction to hue
// \author Vishal Jain
// \date July 7, 2009
//
// \verbatim
//  Modifications
//  <none yet>
// \endverbatim

#include <vcl_string.h>
#include <bprb/bprb_parameters.h>
#include <bvxm/grid/bvxm_voxel_grid_base.h>
#include <bvxm/grid/bvxm_voxel_grid.h>
#include <bvpl/bvpl_kernel_factory.h>
#include <bvpl/bvpl_direction_to_color_map.h>

namespace bvpl_convert_direction_to_hue_process_globals
{
  const unsigned n_inputs_ = 3;
  const unsigned n_outputs_ = 1;
}


//: set input and output types
bool bvpl_convert_direction_to_hue_process_cons(bprb_func_process& pro)
{
  using namespace bvpl_convert_direction_to_hue_process_globals;
  //This process has no inputs nor outputs only parameters
  vcl_vector<vcl_string> input_types_(n_inputs_);
  unsigned i=0;
  input_types_[i++]="bvxm_voxel_grid_base_sptr"; //the inpud grid
  input_types_[i++]="bvpl_kernel_vector_sptr"; //the datatype e.g. "float","double", "vnl_vector_fixed_float_3"...
  input_types_[i++]="vcl_string"; //output directory

  if (!pro.set_input_types(input_types_))
    return false;
  vcl_vector<vcl_string> output_types_(n_outputs_);
  i=0;
  output_types_[i++]="bvxm_voxel_grid_base_sptr"; //the output grid
  if (!pro.set_output_types(output_types_))
    return false;

  return true;
}


//: Execute the process
bool bvpl_convert_direction_to_hue_process(bprb_func_process& pro)
{
  using namespace bvpl_convert_direction_to_hue_process_globals;
  // check number of inputs
  if (pro.input_types().size() != n_inputs_)
  {
    vcl_cout << pro.name() << "The number of inputs should be " << n_inputs_ << vcl_endl;
    return false;
  }

  bvxm_voxel_grid_base_sptr grid_base = pro.get_input<bvxm_voxel_grid_base_sptr>(0);
  bvpl_kernel_vector_sptr kernel = pro.get_input<bvpl_kernel_vector_sptr>(1);
  vcl_string output_dir = pro.get_input<vcl_string>(2);

  if (!grid_base.ptr())  {
    vcl_cerr << "In bvpl_convert_direction_to_hue_process -- input grid is not valid!\n";
    return false;
  }
  if ((bvxm_voxel_grid<vnl_vector_fixed<float,4> > *grid
       = dynamic_cast< bvxm_voxel_grid<vnl_vector_fixed<float,4> >* >(grid_base.ptr())))
  {
    vcl_vector<vgl_point_3d<double> > direction_samples;
    bvpl_generate_direction_samples_from_kernels(kernel,direction_samples);
    vcl_map<vgl_point_3d<double>,float,point_3d_cmp>  colors;
    bvpl_direction_to_color_map(direction_samples,colors);
    bvxm_voxel_grid<vnl_vector_fixed<float,4> > * out_grid
      = new bvxm_voxel_grid<vnl_vector_fixed<float,4> >(output_dir, grid->grid_size());

    bvpl_convert_grid_to_hsv_grid(grid,out_grid,colors );
    pro.set_output_val<bvxm_voxel_grid_base_sptr>(0, out_grid);
    return true;
  }
  else {
    vcl_cerr << "datatype not supported\n";
  }

  return false;
}

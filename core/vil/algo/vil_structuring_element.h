#ifndef vil2_structuring_element_h_
#define vil2_structuring_element_h_
//: \file
//  \brief Structuring element for morphology represented as a list of non-zero pixels
//  \author Tim Cootes

#include <vcl_vector.h>
#include <vcl_iostream.h>

//: Structuring element for morphology represented as a list of non-zero pixels
// Elements in box bounded by [min_i(),max_i()][min_j(),max_j()]
// Non-zero pixels are given by (p_i[k],p_j[k])
class vil2_structuring_element {
private:
  //: i position of elements (i,j)
  vcl_vector<int> p_i_;
  //: j position of elements (i,j)
  vcl_vector<int> p_j_;
  //: Elements in box bounded by [min_i_,max_i_][min_j_,max_j]
  int min_i_;
  //: Elements in box bounded by [min_i_,max_i_][min_j_,max_j]
  int max_i_;
  //: Elements in box bounded by [min_i_,max_i_][min_j_,max_j]
  int min_j_;
  //: Elements in box bounded by [min_i_,max_i_][min_j_,max_j]
  int max_j_;

public:
  vil2_structuring_element()
    : min_i_(0),max_i_(-1),min_j_(0),max_j_(-1) {}

	//: Define elements { (p_i[k],p_j[k]) }
  void set(const vcl_vector<int>& p_i,const vcl_vector<int>& p_j);

  //: i position of elements (i,j)
  const vcl_vector<int>& p_i() const { return p_i_; }
  //: j position of elements (i,j)
  const vcl_vector<int>& p_j() const { return p_j_; }

  //: Elements in box bounded by [min_i(),max_i()][min_j(),max_j()]
  int min_i() const { return min_i_; }
  //: Elements in box bounded by [min_i(),max_i()][min_j(),max_j()]
  int max_i() const { return max_i_; }
  //: Elements in box bounded by [min_i(),max_i()][min_j(),max_j()]
  int min_j() const { return min_j_; }
  //: Elements in box bounded by [min_i(),max_i()][min_j(),max_j()]
  int max_j() const { return max_j_; }
};

//: Write details to stream
vcl_ostream& operator<<(vcl_ostream& os, const vil2_structuring_element& element);

//: Generate a list of offsets for use on image with istep,jstep
//  On exit offset[k] = element.p_i()[k]*istep +  element.p_j()[k]*jstep
//  Gives an efficient way of looping through all the pixels in the structuring element
void vil2_compute_offsets(vcl_vector<int>& offset,
                          const vil2_structuring_element& element, int istep, int jstep);

#endif

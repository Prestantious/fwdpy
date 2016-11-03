from libcpp.vector cimport vector
from fwdpy.fwdpy cimport uint
from cython_gsl cimport gsl_matrix 

cdef extern from "gsl_data_matrix.hpp" namespace "fwdpy::gsl_data_matrix" nogil:
    vector[uint] get_mut_keys[POPTYPE](const POPTYPE * pop, const bint sort_freq, const bint sort_esizes) 
    void update_matrix_counts[POPTYPE] (const POPTYPE *pop, const vector[uint] &mut_keys, gsl_matrix * m)


# distutils: language = c++
# distutils: sources = fwdpy/qtrait/qtrait_impl.cc fwdpy/qtrait/ew2010.cc

#fwdpy/qtrait/ewvw.cc

from cython.operator cimport dereference as deref,preincrement as inc
from libcpp.vector cimport vector
from libcpp.map cimport map
from libcpp.utility cimport pair
from libcpp.string cimport string
from fwdpy.fwdpy cimport *
from fwdpy.internal.internal cimport shwrappervec
import fwdpy.internal as internal
import pandas

cdef extern from "types.hpp" namespace "fwdpy" nogil:
    cdef struct qtrait_stats_cython:
        string stat
        double value
        unsigned gen

    vector[qtrait_stats_cython] convert_qtrait_stats( const singlepop_t * pop )

cdef extern from "qtrait/qtraits.hpp" namespace "fwdpy::qtrait" nogil:
    void evolve_qtraits_t( GSLrng_t * rng, vector[shared_ptr[singlepop_t] ] * pops,
        const unsigned * Nvector,
        const size_t Nvector_length,
        const double mu_neutral,
        const double mu_selected,
        const double littler,
        const double f,
        const double sigmaE,
        const double optimum,
        const double VS,
        const int track,
        const int trackStats,
        const region_manager * rm)

    cdef struct ew_mut_details:
       double s
       double e
       double p
    map[double,ew_mut_details] ew2010_assign_effects(GSLrng_t * rng, const singlepop_t * pop, const double tau, const double sigma) except +
    vector[double] ew2010_traits_cpp(const singlepop_t * pop, const map[double,ew_mut_details] & effects) except +


include "evolve_qtraits.pyx"
include "ew2010.pyx"
include "misc.pyx"




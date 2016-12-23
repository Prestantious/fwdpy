from cython_gsl.gsl_blas cimport *
from cython_gsl.gsl_linalg cimport * 
from cython_gsl.gsl_math cimport * 
from libcpp.limits cimport numeric_limits

#These are unique_ptr wrappers around
#the GSL pointer types.
from fwdpy.gsl cimport gsl_vector_ptr_t,gsl_matrix_ptr_t 
#It is uncool to allow GSL to handle its errors in the default way,
#so we need to manually handle things
from fwdpy.gsl cimport gsl_error_handler_t,gsl_set_error_handler_off,gsl_set_error_handler

cdef pair[double,vector[double]] sum_of_squares(const gsl_vector * v,
                                                gsl_matrix * m) nogil:
    #Turn of GSL error handling
    cdef gsl_error_handler_t * error_handler = gsl_set_error_handler_off()

    cdef numeric_limits[double] nld
    cdef pair[double,vector[double]] rv
    #Set total sum of squars to not-a-number
    #in case we return due to an error
    rv.first=nld.quiet_NaN()
    if v.size != m.size1:
        #Bad stuff, so return nonsensical value
        gsl_set_error_handler(error_handler)
        return rv

    cdef gsl_vector_ptr_t TAU,SUMS
    cdef gsl_matrix_ptr_t Q,R

    TAU.reset(gsl_vector_alloc(min(m.size1,m.size2)))
    if TAU.get() == NULL:
        gsl_set_error_handler(error_handler)
        return rv
    SUMS.reset(gsl_vector_alloc(m.size1))
    if SUMS.get() == NULL:
        gsl_set_error_handler(error_handler)
        return rv
    Q.reset(gsl_matrix_alloc(m.size1,m.size1))
    if Q.get() == NULL:
        gsl_set_error_handler(error_handler)
        return rv
    R.reset(gsl_matrix_alloc(m.size1,m.size2))
    if R.get() == NULL:
        gsl_set_error_handler(error_handler)
        return rv

    cdef int gsl_rv
    gsl_rv = gsl_linalg_QR_decomp(m,TAU.get())
    gsl_rv = gsl_linalg_QR_unpack(m,TAU.get(),Q.get(),R.get())
    gsl_rv = gsl_blas_dgemv(CblasTrans,1.0,Q.get(),v,0.0,SUMS.get())

    cdef size_t i
    for i in range(0,m.size2): 
        rv.second.push_back(gsl_pow_2(gsl_vector_get(SUMS.get(),i+1)))
   
    cdef size_t DF = m.size2-1
    RSS=0.0
    for i in range(DF+1,SUMS.get().size):
        RSS += gsl_pow_2(gsl_vector_get(SUMS.get(),i))

    cdef double sqi=0.
    rv.first = RSS
    for sqi in rv.second: rv.first += sqi

    gsl_set_error_handler(error_handler)
    return rv


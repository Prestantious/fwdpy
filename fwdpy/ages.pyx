from cython.parallel import parallel, prange

def allele_ages( const vector[vector[freqTraj]] & trajectories, double minfreq = 0.0, unsigned minsojourn = 1 ):
    """
    Calculate allele age information from mutation frequency trajectories.

    The return value is a list of dicts that include the generation when the mutation arose, its effect size, 
    maximum frequency, and the number of times a frequency was recorded for that mutation.
    """
    cdef size_t nt = trajectories.size()
    cdef vector[vector[allele_age_data_t]] rv
    rv.resize(nt)
    cdef int i
    for i in prange(nt,schedule='static',nogil=True,chunksize=1):
        rv[i] = allele_ages_details(trajectories[i],minfreq,minsojourn)

    return rv

def merge_trajectories( const vector[vector[freqTraj]] & trajectories1,
                        const vector[vector[freqTraj]] & trajectories2 ):
    """
    Take two sets of mutation trajectories and merge them.

    The intended use case is that trajectories2 are from a later time point of the same
    simulations used to generate trajectories 1.  For example, trajectories 1 may represent 
    mutations arising during evolutoin to equilibtrium, and trajectories2 represent what happend
    during a bottleneck.
    """
    if trajectories1.size() != trajectories2.size():
        raise RuntimeError("the two input lists must be the same length")

    cdef size_t nt = trajectories1.size()
    cdef vector[vector[freqTraj]] rv
    rv.resize(nt)
    cdef int i
    
    for i in prange(nt,schedule='static',nogil=True,chunksize=1):
        rv[i] = merge_trajectories_details(trajectories1[i],trajectories2[i])

    return rv

def tidy_trajectories( const vector[vector[freqTraj]] & trajectories, unsigned min_sojourn = 0, double min_freq = 0.0):
    """
    Take a set of allele frequency trajectories and 'tidy' them for easier coercion into
    a pandas.DataFrame.

    :param trajectories: A container of mutation frequency trajectories from a simulation.
    :param min_sojourn: Exclude mutations that segregate for fewer generations than this value.
    :param min_freq: Exclude mutations that never reach a frequency :math:`\\geq` this value.

    .. note:: The sojourn time filter is not applied to fixations.  I'm assuming you are always interested in those.
    """
    cdef vector[vector[selected_mut_data_tidy]] rv;
    rv.resize(trajectories.size())
    cdef size_t nt = trajectories.size()
    cdef int i

    for i in prange(nt,schedule='static',nogil=True,chunksize=1):
        rv[i]=tidy_trajectory_info(trajectories[i],min_sojourn,min_freq)

    return rv

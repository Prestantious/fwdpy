#See http://docs.cython.org/src/userguide/memoryviews.html
from cython.view cimport array as cvarray
import numpy as np

def evolve_regions(GSLrng rng,
                    int npops,
                    int N,
                    unsigned[:] nlist,
                    double mu_neutral,
                    double mu_selected,
                    double recrate,
                    list nregions,
                    list sregions,
                    list recregions,
                    double f = 0,
                    const char * fitness = "multiplicative"):
    """
    Evolve a region with variable mutation, fitness effects, and recombination rates.

    :param rng: a :class:`GSLrng`
    :param npops: The number of populations to simulate.  This is equal to the number of threads that will be used!
    :param N: The diploid population size to simulate
    :param nlist: An array view of a NumPy array.  This represents the population sizes over time.  The length of this view is the length of the simulation in generations. The view must be of an array of 32 bit, unsigned integers (see example).
    :param mu_neutral: The mutation rate to variants not affecting fitness ("neutral" mutations).  The unit is per gamete, per generation.
    :param mu_selected: The mutation rate to variants affecting fitness ("selected" mutations).  The unit is per gamete, per generation.
    :param recrate: The recombination rate in the regions (per diploid, per generation)
    :param nregions: A list specifying where neutral mutations occur
    :param sregions: A list specifying where selected mutations occur
    :param recregions: A list specifying how the genetic map varies along the region
    :param f: The selfing probabilty
    :param fitness: The fitness model.  Must be either "multiplicative" or "additive".

    Example:

    >>> import fwdpy
    >>> import numpy as np
    >>> #Our "neutral" regions will be from positions [0,1) and [2,3).
    >>> #The regions will have equal weights, and thus will each get
    >>> #1/2 of newly-arising, neutral mutations
    >>> nregions = [fwdpy.Region(0,1,1),fwdpy.Region(2,3,1)]
    >>> #Our "selected" mutations will have positions on the continuous
    >>> #interval [1,2).  There will be two classes of such mutations,
    >>> #each with exponentially-distrubted selection coefficients.
    >>> #The first class will have a mean of s = -0.1 (deleterious), and the second
    >>> #will have a mean of 1e-3 (adaptive).  The former will be 100x more common than
    >>> #the latter, as the weights are 1 and 0.01, respectively.
    >>> sregions = [fwdpy.ExpS(1,2,1,-0.1),fwdpy.ExpS(1,2,0.01,0.001)]
    >>> #Recombination will be uniform along the interval [0,3).
    >>> rregions = [fwdpy.Region(0,3,1)]
    >>> rng = fwdpy.GSLrng(100)
    >>> #popsizes are NumPy arrays of 32bit unsigned integers
    >>> #Initial pop size will be N = 1,000, and
    >>> #the type must be uint32 (32 bit unsigned integer)
    >>> popsizes = np.array([1000],dtype=np.uint32)
    >>> #The simulation will be for 10*N generations,
    >>> #so we replicate that value in the array
    >>> popsizes=np.tile(popsizes,10000)
    >>> #Simulate 1 deme under this model.
    >>> #The total neutral mutation rate is 1e-3,
    >>> #which is also the recombination rate.
    >>> #The total mutation rate to selected variants is 0.1*(the neutral mutation rate).
    >>> pops = fwdpy.evolve_regions(rng,1,1000,popsizes[0:],0.001,0.0001,0.001,nregions,sregions,rregions)
    """
    pops = popvec(npops,N)
    nreg = process_regions(nregions)
    sreg = process_regions(sregions)
    recreg = process_regions(recregions)
    v = shwrappervec()
    process_sregion_callbacks(v,sregions)
    evolve_regions_t(rng.thisptr,&pops.pops,&nlist[0],len(nlist),mu_neutral,mu_selected,recrate,f,nreg['beg'].tolist(),nreg['end'].tolist(),nreg['weight'].tolist(),
                    sreg['beg'].tolist(),sreg['end'].tolist(),sreg['weight'].tolist(),&v.vec,
                    recreg['beg'].tolist(),recreg['end'].tolist(),recreg['weight'].tolist(),
                    fitness)
    return pops
    
                
def evolve_regions_more(GSLrng rng,
                        popvec pops,
                        unsigned[:] nlist,
                        double mu_neutral,
                        double mu_selected,
                        double recrate,
                        list nregions,
                        list sregions,
                        list recregions,
                        double f = 0,
                        const char * fitness = "multiplicative"):
    """
    Continute to evolve a region with variable mutation, fitness effects, and recombination rates.

    :param rng: a :class:`GSLrng`
    :param pops: A list of populations simulated by :func:`evolve_regions`
    :param N: The diploid population size to simulate
    :param nlist: An array view of a NumPy array.  This represents the population sizes over time.  The length of this view is the length of the simulation in generations. The view must be of an array of 32 bit, unsigned integers (see example).
    :param mu_neutral: The mutation rate to variants not affecting fitness ("neutral" mutations).  The unit is per gamete, per generation.
    :param mu_selected: The mutation rate to variants affecting fitness ("selected" mutations).  The unit is per gamete, per generation.
    :param recrate: The recombination rate in the regions (per diploid, per generation)
    :param nregions: A list specifying where neutral mutations occur
    :param sregions: A list specifying where selected mutations occur
    :param recregions: A list specifying how the genetic map varies along the region
    :param f: The selfing probabilty
    :param fitness: The fitness model.  Must be either "multiplicative" or "additive".

    Example:

    >>> # See docstring for fwdpy.evolve_regions for the gory details
    >>> import fwdpy
    >>> import numpy as np
    >>> nregions = [fwdpy.Region(0,1,1),fwdpy.Region(2,3,1)]
    >>> sregions = [fwdpy.ExpS(1,2,1,-0.1),fwdpy.ExpS(1,2,0.01,0.001)]
    >>> rregions = [fwdpy.Region(0,3,1)]
    >>> rng = fwdpy.GSLrng(100)
    >>> popsizes = np.array([1000],dtype=np.uint32)
    >>> # Evolve for 5N generations initially
    >>> popsizes=np.tile(popsizes,5000)
    >>> pops = fwdpy.evolve_regions(rng,1,1000,popsizes[0:],0.001,0.0001,0.001,nregions,sregions,rregions)
    >>> # Evolve for another 5N generations
    >>> fwdpy.evolve_regions_more(rng,pops,popsizes[0:],0.001,0.0001,0.001,nregions,sregions,rregions)
    """
    nreg = process_regions(nregions)
    sreg = process_regions(sregions)
    recreg = process_regions(recregions)
    v = shwrappervec()
    process_sregion_callbacks(v,sregions)
    evolve_regions_t(rng.thisptr,&pops.pops,&nlist[0],len(nlist),mu_neutral,mu_selected,recrate,f,nreg['beg'].tolist(),nreg['end'].tolist(),nreg['weight'].tolist(),
                    sreg['beg'].tolist(),sreg['end'].tolist(),sreg['weight'].tolist(),&v.vec,recreg['beg'].tolist(),recreg['end'].tolist(),recreg['weight'].tolist(),
                    fitness)

# GraphUtilities

[![CI](https://github.com/RydbergBoston/GraphUtilities.jl/actions/workflows/ci.yml/badge.svg)](https://github.com/RydbergBoston/GraphUtilities.jl/actions/workflows/ci.yml)


## Workflow
0. Setup environment
Install related packages in julia `pkg>` mode
```julia
pkg> add https://github.com/RydbergBoston/GraphUtilities.jl.git#master

pkg> instantiate project
```

1. Generate a graph instance and dump it to a working folder, and generate the contraction order optimized tensor network,

Type the following in a terminal in the main folder of this repo to create a random 3-regular graph to solve the independent set problem
```bash
$ julia --project project/run.jl generate regular IndependentSet 20 --degree=3 --datafolder=data2 --seed=1
[ Info: OMEinsum loaded the CUDA module successfully
[ Info: writing configuration to: data2/IndependentSet_Regular20d3seed1/info.toml
[ Info: saving contraction tree to: data2/IndependentSet_Regular20d3seed1/tensornetwork.json
```
The program will create an graph problem instance and save it in the `data2` folder (`data` folder by default).
Type `julia --project project/run.jl generate -h` for get more help on arguments.

Similarly, you can create the following preset graphs.
* diagonal-coupled unit-disk grid graph at size 20x20, 0.8 filling
```bash
$ julia --project project/run.jl generate diag IndependentSet 20 --filling=0.8
```
* unit-disk square lattice graph at size 20x20, 0.8 filling
$ julia --project project/run.jl generate square IndependentSet 20 --filling=0.8
* unit-disk square lattice graph at size 20x20, 0.8 filling
$ julia --project project/run.jl generate petersen IndependentSet 10
```

Other problems includes `MaxCut`, `DominatingSet`, `MaximalIS`, `Matching`, `Coloring{3}` et al.

2. Compute properties,
```bash
$ julia --project project/run.jl compute regular IndependentSet 20 SizeMax --degree=3 --datafolder=data2 --seed=1
[ Info: OMEinsum loaded the CUDA module successfully
[ Info: loading contraction tree from: data2/IndependentSet_Regular20d3seed1/tensornetwork.json
[ Info: saving result to file/folder: data2/IndependentSet_Regular20d3seed1/SizeMax1.dat
```

3. Load and use properties,
Check function `GraphUtilities.load_property` for details.

(To be written)

## Command examples
1. compute overlap gap property for alpha = 0.1, 3-regular graph of size 110:10:150
```bash
$ julia project/run.jl ogp-regular 110 --seed=1 --seedstop=100 --sizestop=150 --sizestep=10
```

## TODO
1. support hdf5 to avoid small file storage.

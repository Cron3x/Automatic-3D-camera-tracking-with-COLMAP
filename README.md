# Automatic 3D camera tracking with COLMAP and GLOMAP on Linux (and Mac?)
A collection of scripts for automatic 3d camera tracking using COLMAP

## The script
This script is based on [this](https://gist.github.com/polyfjord/4ed7e8988bdb9674145f1c270440200d) script from Polyfjord.

I added a few extra features like disabling the GPU and changing the folder structure, just run the script with -h to see all option.

Its importent to note that this script is currently written for *COLMAP 3.12.4*, some features might change in the future so functionality can not be guaranteed. (Some flags already have changed in the main branch)

Before you can use the script you need to kae it executable with:
```bash
chmod -x <PATH-TO-SCRIPT>
```

## Import into Blender
[Import-Point-Cloud-Addon by SBCV](https://github.com/SBCV/Blender-Import-Point-Cloud-Addon)


## Colmap
[Offical Installation Documentation](https://colmap.github.io/install.html)

### Prebuild Binaries
Colmap can be installed via the [homebrew package manager](https://brew.sh/) on Mac and Linux
[Colmap on Homebrew](https://formulae.brew.sh/formula/colmap)
In my opinion this is the fastest way to set up colmap.

Homebrew unfortunately reinstalls all dependencies need by colmap. What this mean is, you will have two instances of zlib, zstd, wayland and so on. This makes sense from the view of homebrew but is worth a consideration. On my system the homebrew folder grew to ~6gb, maybe I need to change something, but I couln'd find it easily.

### Building from Source
#### VCPKG
[Offical Installation Documentation](https://colmap.github.io/install.html)

>[!NOTE]
>Packages Reured:
>  Fedora: `perl-FindBin`, `autoconf`, `automake` and `libtool`

#### Download everything your self
first go to [COLMAP](https://github.com/colmap/colmap) and download the sourcecode of the latest release.
In the folder you should create a folder called `build` and cd in to it.
than run the following command
```bash
mkdir build
cd ./build/
cmake -S .. -B . -G Ninja
```
you probably will get errors that libraries could not be found, so just go and install them.
When this stepp is completed run 
```bash
ninja
```
now you can run:
```bash
sudo ninja install
```
to install the COLMAP binary.
If you I installed the binary you should provide the path to the it when running the automate.sh script, eg.
```bash
./automate.sh -C /usr/local/bin/colmap
```


> [!NOTE]
> I'm on Fedora 42 and I had an error with conflicting Glog packages.
> For me comenting out 'find_package(Glog ${COLMAP_FIND_TYPE})' in cmake/FindDependencies.cmake fixed the issue.
> If there are anymore issues and fixes, let me know I will add them as well.


# Glomap
[GLOMAP Source](https://github.com/colmap/glomap)
</br>
I had success compiling it on Fedora using `vcpkg` and the latest git version.

These are my installation steps

```bash
git clone https://github.com/colmap/glomap.git
cd glomap
git clone --depth=1 https://github.com/Microsoft/vcpkg.git
./vcpkg/bootstrap-vcpkg.sh  -disableMetrics
```

If you want to get the latest version of colmap or dont want to compile against your local version you should remove `FETCH_COLMAP="OFF"`.

```sh
FETCH_COLMAP="OFF" cmake -B build -GNinja \
  -DCMAKE_TOOLCHAIN_FILE=./vcpkg/scripts/buildsystems/vcpkg.cmake \
  -DCMAKE_CUDA_ARCHITECTURES=native \
  -DCMAKE_CXX_FLAGS="-Wno-error"
```
 > [!NOTE]
 > You might want to install the `autoconf`, `automake` and `libtool` packages if you encouter errors.

For me the ninja compilation crashed because the -Werror for C++ was set. My workaround is to go into buld.ninja and remove it from every line.
If you now how to change the default please let me know. Also it tried to compile against CUDA eventhough I don't hava a NVIDIA GPU, the fix for me was to change the if statment in the CMakeLists.txt

```sh
cd build

ninja

sudo ninja install
```

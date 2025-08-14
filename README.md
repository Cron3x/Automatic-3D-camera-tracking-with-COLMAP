# Automatic-3D-camera-tracking-with-COLMAP
A collection of scripts for automatic 3d camera tracking using COLMAP

## The script
This script is based on [this](https://gist.github.com/polyfjord/4ed7e8988bdb9674145f1c270440200d) script from Polyfjord.
I added a few extra features like disabling the GPU and changing the folder structure, just run the script with -h to see all option.
Its importent to note that this script is currently written for *COLMAP 3.12.4*, some flags might change in the future

## Import into Blender
[Import-Point-Cloud-Addon by SBCV](https://github.com/SBCV/Blender-Import-Point-Cloud-Addon)

## Building Colmap on Linux
first go to [COLMAP](https://github.com/colmap/colmap) and download the sourcecode of the latest release.
In the folder you should create a folder called build and cd in to it.
than run the following command
```bash
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
to install the COLMAP binary

> [!NOTE]
> I'm on Fedora 42 and I had an error with conflicting Glog packages.
> For me comenting out 'find_package(Glog ${COLMAP_FIND_TYPE})' in cmake/FindDependencies.cmake fixed the issue.
> If there are anymore issues and fixes, let me know I will add them as well.

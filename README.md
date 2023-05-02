# mkpexec

The name of this project is short for "make portable executable," and is used to convert a dynamically linked binary into something more portable which could be deployed anywhere.

Due to the difficulty in statically linking certain libraries like X11 and ALSA, this allows you to make a portable executable that contains all of your dependencies without statically linking it.

It functions similarly to Snaps or Flatpak in that it sets up a sandbox that contains all your dependencies, except that the sandbox creation is carried out by the executable itself, and the executable is statically linked with no dependencies.

This means that rather than expecting the user to install something like Flatpack or Snaps, you can distribute your program as a stand-alone executable. The executable will setup the sandbox on its own without any dependencies as it is statically linked, and then run your program within that sandbox.

Converting a program to this portable format is as simple as running "./mkpexec myprogram". It will then produce a "myprogram.static" which should have the same behavior as "myprogram" except now will contain all of its dependencies.

Please note that this adds a LOT of bloat to your binary, so only do this if size isn't a big concern to you. The bloat is in the megabytes.

The software sets up the sandbox using proot, however proot is not a dependency as it will statically build proot and include it within the ".static" binary as part of the compilation process.

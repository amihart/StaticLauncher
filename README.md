# StaticLauncher
Converts a dynamic binary into a static binary by wrapping it in a static launcher.

This imports all the dependencies into the binary which increases its size, typically in the megabytes. This is good for creating a portable binary that can run on different Linux distributions independent of what is installed onto it. If the portability is more desirable than the bloat of all the dependencies, then this script is for you.

I do not recommend using this if your program has security-related dependencies, since regular updates are important for those and if you import your dependencies into a binary, then if the user updates their machine the dependency in the binary will not be updated.

Just run the static_launcher.sh script followed by the name of the binary.

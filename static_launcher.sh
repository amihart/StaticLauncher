#!/bin/sh

if [ -z "$1" ]
then
	echo "usage: static_launcher [file_name]"
	exit
fi

if [ -e "$1" ]
then
	projfile="$1"
else
	echo "File not found."
	exit
fi

tmpdir="$(mktemp -d)"
projfile=$(readlink -f "$projfile")

cd "$tmpdir"

libs=$(ldd "$projfile" | grep '=>' | sed -e 's/.*=>//' -e 's/(.*//' | xargs)
libs="$projfile $libs"
filenames=""
ogfilenames=""

for lib in $libs
do
	bname=$(basename "$lib")
	dname=$(dirname "$lib")
	hname=$(echo "$bname" | sed -e 's/\./\_/g').h
	echo "Exporting $bname . . ."
	echo -n "const " > "$hname"
	xxd -i "$lib" >> "$hname"
	filenames="$filenames $hname"
done

out=___launcher___.c
echo "//automatically generated" > $out
for file in $filenames
do
	echo -n '#include "' >> $out
	echo -n "$file" >> $out
	echo '"' >> $out
done

fncount=$(echo "$filenames" | awk '{print NF}')

cat >> "$out" << HERE
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/stat.h>
#include <limits.h>
HERE

echo "size_t shared_libraries_count;" >> "$out" 
echo "size_t shared_libraries_length[$fncount];" >> "$out" 
echo "const char *shared_libraries[$fncount];" >> "$out"
echo "const char *shared_libraries_name[$fncount];" >> "$out"
echo "void definitions()" >> "$out"
echo "{" >> "$out"
i=0
for file in $filenames
do
	vname=$(head -n 1 "$file" | sed -e 's/.*unsigned char//' -e 's/\[\].*//' | xargs)
	vname_len=$(tail -n 1 "$file" | sed -e 's/.*unsigned int//' -e 's/\=.*//' | xargs)
	vname_lib=$(echo "$libs" | cut -d ' ' -f $((1 + i)))
	vname_lib=$(basename "$vname_lib")
	echo "	shared_libraries[$i] = $vname;" >> "$out"
	echo "	shared_libraries_length[$i] = $vname_len;" >> "$out"
	echo "	shared_libraries_name[$i] = \"$vname_lib\";" >> "$out"
	i=$((i+1))
done
echo "}" >> "$out"

cat >> "$out" << HERE

char template[] = "/tmp/static_launcher.XXXXXX";
char *tmpdir = NULL;
char path[PATH_MAX];

void get_tmp_path(const char* name)
{
	strcpy(path, tmpdir);
	path[strlen(template)] = '/';
	strcpy(path + strlen(template) + 1, name);
}

void setup()
{
	tmpdir = mkdtemp(template);
	if (tmpdir == NULL)
	{
		perror("mkdtemp");
		exit(1);
	}

	shared_libraries_count = $fncount;
	for (size_t i = 0; i < shared_libraries_count; i++)
	{
		get_tmp_path(shared_libraries_name[i]);
		FILE *f = fopen(path, "w");
		if (f == NULL)
		{
			fprintf(stderr, "Failed to write file. Please manually remove the folder %s\n.", tmpdir);
			exit(1);
		}
		fwrite(shared_libraries[i], shared_libraries_length[i], 1, f);
		fclose(f);
		if (i == 0)
		{
			if (chmod(path, S_IRUSR | S_IWUSR | S_IXUSR) != 0)
			{
				perror("chmod");
				fprintf(stderr, "Failed to extract launcher. Please manually remove the folder %s\n.", tmpdir);
				exit(1);
			}
		}
	}
}

void cleanup()
{
	for (size_t i = 0; i < shared_libraries_count; i++)
	{
		get_tmp_path(shared_libraries_name[i]);
		if (unlink(path) != 0)
		{
			fprintf(stderr, "Failed to clean up. Please manually remove the folder %s\n.", tmpdir);
			exit(1);
		}
	}
	if (rmdir(tmpdir) == -1)
	{
		perror("rmdir");
		exit(1);
	}
}

int main(int argc, char **argv)
{
	definitions();
	setup();
	get_tmp_path("$(basename "$projfile")");
	const char command_export_start[] = "export LD_LIBRARY_PATH=";
	const char command_export_end[] = " && ";

	size_t command_len = strlen(command_export_start) + 1;
	char *command = malloc(command_len);
	strcpy(command, command_export_start);

	command_len += strlen(tmpdir);
	command = realloc(command, command_len);
	strcat(command, tmpdir);

	command_len += strlen(command_export_end);
	command = realloc(command, command_len);
	strcat(command, command_export_end);

	command_len += strlen(path);
	command = realloc(command, command_len);
	strcat(command, path);
	
	for (int i = 1; i < argc; i++)
	{
		command_len += 1;
		command = realloc(command, command_len);
		strcat(command, " ");
		command_len += strlen(argv[i]);
		command = realloc(command, command_len);
		strcat(command, argv[i]);
	}
	int return_value = system(command);
	free(command);
	cleanup();
	return return_value;
}

HERE

binout=$(dirname "$projfile")
binout="$binout/"
projfile=$(basename "$projfile")
if echo "$projfile" | grep -i ".exe" > /dev/null
then
        projfile=$(echo "$projfile" | sed -e 's/\.exe//i')
	binout="$binout$projfile.static.exe"
else
	binout="$binout$projfile.static"
fi

echo "Building launcher . . ."
gcc -static "$out" -o "$binout"

echo "Cleaning up . . ."
rm -r "$tmpdir"

echo "Done."

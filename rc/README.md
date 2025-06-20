# STRM Functions source directory

In order to use the functions in this directory, you'll need to source them and make them available to your shell.
You can use the following to source all files in the `rc` directory:
```bash
for f in $(find change/this/path/to/rc -type f -not -name "README*" | xargs -I% realpath "%"); do source $f; done
```

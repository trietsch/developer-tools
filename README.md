# Developer Tools

A toolbox full of useful scripts and functions, that you can use as a software engineer.

## Scripts / Binaries

Can be found in the `/bin` directory. Make sure to add this directory to your path:

```bash
export PATH="path/to/developer-tools/bin:$PATH"
```

## Source files

Can be found in the `/rc` directory. In order to use the functions in this directory, you'll need to source them and
make them available to your shell.
You can use the following to source all files in the `rc` directory:

```bash
for f in $(find path/to/developer-tools/rc -type f -not -name "README*" | xargs -I% realpath "%"); do source $f; done
```


# atom-slime package

Integrates SLIME (the Superior Lisp Interaction Mode for Emacs) with Atom! This package allows you to interactively develop Common Lisp code, helping turn Atom into a full-featured Lisp IDE.

Current features of this package:

- Read-eval-print-loop (REPL) for interactive Lisp development
- Integrated debugger (work in progress on stack trace)
- Jumping to a method definition (use alt-., or the `slime:goto-definition` command)
- Autocomplete suggestions from swank
- Autodocumentation

Future features:
- Interactive object inspection
- Stack trace in debugger
- "Compile this function" command


**Note**: This package is still in beta and in active development! Contributions and bug reports are welcome.

System Requirements
-------------------
Here are the requirements for using `atom-slime`:

- Lisp (known to work with SBCL 1.2.12 and greater)
- The swank code. If you run Emacs and have used SLIME before, you already have it installed. If not, check it out from https://github.com/slime/slime.git

The following may not be strictly necessary but are highly recommended:
- The `language-lisp` atom package (https://atom.io/packages/language-lisp)
- The `lisp-paredit` atom package (https://atom.io/packages/lisp-paredit)

How to run
------------

First, you'll need to start a swank server in lisp. For example, if you use SBCL, run the following in a terminal:

```
cd /directory/to/where/you/have/slime-swank
sbcl --load start-swank.lisp
```

Once that's running, you  have a Lisp processing running a swank server awaiting connections. The next step is to connect to it via the `atom-slime` package.

Within Atom, run the `Slime: Connect` command from the command palette. That will connect to the Lisp swank server. The REPL should now become visible and should work.

Additionally, if you open a *.lisp file and start typing functions or move the cursor over functions, you'll autodocumentation strings appear in the status bar.

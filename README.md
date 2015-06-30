# atom-slime package

This package integrates SLIME (the Superior Lisp Interaction Mode for Emacs) with Atom! It allows you to interact with a running lisp process running a "swank server."

Current features of this package:

- Read-eval-print-loop (REPL) for interactive Lisp development (partial support)
- Autodocumentation

Future features:
- "Go to method definition" etc.
- Integrated debugger
- Autocomplete suggestions
- Improve sleakness to the above

**Note**: This package is still in development! Contributions welcome.

System Requirements
-------------------
Here are the requirements for using atom-slime:

- Lisp (known to work with SBCL 1.2.12 and greater)
- The swank code. If you run Emacs and have used SLIME before, you already have it installed. If not, check it out from https://github.com/slime/slime.git

The following may not strictly be necessary but is highly recommended:
- The `language-lisp` atom package (https://atom.io/packages/language-lisp)
- The `lisp-paredit` atom package (https://atom.io/packages/lisp-paredit)

How to run
------------

First, you'll need to start a swank server in lisp. For example, if you use SBCL as your Lisp, run the following in a terminal:

```
cd /directory/to/where/you/have/slime-swank
sbcl --load start-swank.lisp
```

Once that's running, you  have a Lisp processing running a swank server awaiting connections. The next step is to connect to it via the Atom slim plugin.

Within atom, run the `Slime: Connect` from the command pallet. That will connect to slime! The REPL should now work.

Additionally, if you open a *.lisp file and start typing functions or move the cursor over functions, you'll autodocumentation strings appear in the status bar.

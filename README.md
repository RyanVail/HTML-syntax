# HTML-Syntax

A simple Python syntax highlighter that generates static HTML, built with Zig.

![Highlighted python code](examples/example.png)

## Features
  * Compiles into static HTML
  * fstring highlighting
  * Highly extensible
  * Simple CLI
  * Highly customizable CSS
  * Support for hex, octal, binary, and scientific notation

## Building
  * Download [Zig](https://ziglang.org)
  * Execute `zig build -Doptimize=ReleaseSafe`
  * Binary located in `zig-out/bin/`

## Usage
  * html\_coder **[SOURCE FILE]** **[OUTPUT FILE]**
  * Apply a stylesheet, example stylesheet: [style.css](examples/style.css)

## Example
  * [Python](examples/example.py) source file
  * [HTML](examples/examples.html) result (stylying added manually)
  * [CSS](examples/style.css) used
  * [Screenshot](examples/example.png) Rendered with Firefox

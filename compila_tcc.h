#!/bin/bash
pdflatex tcc1_maxwell.tex
biber tcc1_maxwell
pdflatex tcc1_maxwell.tex
pdflatex tcc1_maxwell.tex

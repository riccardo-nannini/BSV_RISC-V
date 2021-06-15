main := report

.PHONY: clean distclean

LTC = pdflatex -interaction=nonstopmode -shell-escape -synctex=1
BIB = biber

other_texs = $(filter-out $(main).tex, $(wildcard *.tex))

all: $(main).pdf

$(main).pdf: $(main).tex $(other_texs)
	$(LTC) $(main).tex
ifeq (,$(wildcard ./*.bib))
	$(BIB) $(main)
endif
	$(LTC) $(main).tex
	$(LTC) $(main).tex
	$(LTC) $(main).tex

clean:
	@rm -f *.aux *.bbl $(main).blg $(main).dvi $(main).log $(main).out \
	$(main).ps $(main).synctex.gz *.blg *.xml *-blx.bib *.bcf &> /dev/null || true

distclean: clean
	@rm $(main).pdf &> /dev/null || true


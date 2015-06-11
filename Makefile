all:
	elm make --yes src/Main.elm --output=public/elm.js

deps:
	git submodule init
	git submodule update
	elm package install --yes
	npm install

loc:
	find src -regex ".*elm" | xargs wc -l
	find elm-diagrams/Diagrams -regex ".*elm" | xargs wc -l


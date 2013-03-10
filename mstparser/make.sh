rm mstparser/*.class
javac -nowarn -O -source 1.4 -classpath ".:lib/trove.jar" mstparser/DependencyParser.java


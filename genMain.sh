#! /bin/bash -

# generate a Java source file collecting all class names that extend
# WindowController

# compile by "javac -cp objectdraw.jar:. Main.java"
# run by "java -cp objectdraw.jar:. Main"

OUTPUT=Main.java

cat <<EOF > $OUTPUT
import objectdraw.*;
import java.awt.*;

public class Main {
  public static void main(String[] args) {
EOF
i=0
for c in `grep "extends WindowController" *.java | cut -d " " -f 3`; do
    echo "    $c window$i = new $c();" >> $OUTPUT
    echo "    window$i.setName(\"$c\");" >> $OUTPUT
    echo "    window$i.startController();" >> $OUTPUT
    echo "" >> $OUTPUT
    ((i++))
done
echo -e '  }\n}' >> $OUTPUT


package mstparser;

import java.io.*;
import mstparser.io.*;

public class DependencyEvaluator {
	
    public static void evaluate (String act_file, 
				 String pred_file, 
				 String format) throws IOException {
	
	DependencyReader goldReader = DependencyReader.createDependencyReader(format);
	boolean labeled = goldReader.startReading(act_file);

	DependencyReader predictedReader = DependencyReader.createDependencyReader(format);
	boolean predLabeled = predictedReader.startReading(pred_file);

	if (labeled != predLabeled)
	    System.out.println("Gold file and predicted file appear to differ on whether or not they are labeled. Expect problems!!!");


	int total = 0; int corr = 0; int corrL = 0;
	int numsent = 0; int corrsent = 0; int corrsentL = 0;
	int root_act = 0; int root_guess = 0; int root_corr = 0;

	DependencyInstance goldInstance = goldReader.getNext();
	DependencyInstance predInstance = predictedReader.getNext();

	while(goldInstance != null) {

	    int instanceLength = goldInstance.length();

	    if (instanceLength != predInstance.length())
		System.out.println("Lengths do not match on sentence "+numsent);

	    int[] goldHeads = goldInstance.heads;
	    String[] goldLabels = goldInstance.deprels;
	    int[] predHeads = predInstance.heads;
	    String[] predLabels = predInstance.deprels;

	    boolean whole = true;
	    boolean wholeL = true;

	    // NOTE: the first item is the root info added during nextInstance(), so we skip it.

	    for (int i = 1; i < instanceLength; i++) {
		if (predHeads[i] == goldHeads[i]) {
		    corr++;
		    if (labeled) {
			if (goldLabels[i].equals(predLabels[i])) 
			    corrL++;
			else 
			    wholeL = false;
		    }
		}
		else { 
		    whole = false; wholeL = false; 
		}
	    }
	    total += instanceLength - 1; // Subtract one to not score fake root token

	    if(whole) corrsent++;
	    if(wholeL) corrsentL++;
	    numsent++;
						
	    goldInstance = goldReader.getNext();
	    predInstance = predictedReader.getNext();
	}

	System.out.println("Tokens: " + total);
	System.out.println("Correct: " + corr);
	System.out.println("Unlabeled Accuracy: " + ((double)corr/total));
	System.out.println("Unlabeled Complete Correct: " + ((double)corrsent/numsent));
	if(labeled) {
	    System.out.println("Labeled Accuracy: " + ((double)corrL/total));
	    System.out.println("Labeled Complete Correct: " + ((double)corrsentL/numsent));
	}
		
    }

    public static void main (String[] args) throws IOException {
	String format = "CONLL";
	if (args.length > 2)
	    format = args[2];

	evaluate(args[0], args[1], format);
    }

}

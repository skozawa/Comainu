package mstparser;

public class KBestParseForest2O {

    private ParseForestItem[][][][][] chart;
    private String[] sent,pos;
    private int start,end;
    private int K;
	
    public KBestParseForest2O(int start, int end, DependencyInstance inst, int K) {
	this.K = K;
	chart = new ParseForestItem[end+1][end+1][2][3][K];
	this.start = start;
	this.end = end;
	this.sent = inst.forms;
	this.pos = inst.postags;
    }

    public boolean add(int s, int type, int dir, double score, FeatureVector fv) {
				
	boolean added = false;

	if(chart[s][s][dir][0][0] == null) {
	    for(int i = 0; i < K; i++)
		chart[s][s][dir][0][i] = new ParseForestItem(s,type,dir,Double.NEGATIVE_INFINITY,null);
	}
		
	if(chart[s][s][dir][0][K-1].prob > score)
	    return false;

	for(int i = 0; i < K; i++) {
	    if(chart[s][s][dir][0][i].prob < score) {
		ParseForestItem tmp = chart[s][s][dir][0][i];
		chart[s][s][dir][0][i] = new ParseForestItem(s,type,dir,score,fv);
		for(int j = i+1; j < K && tmp.prob != Double.NEGATIVE_INFINITY; j++) {
		    ParseForestItem tmp1 = chart[s][s][dir][0][j];
		    chart[s][s][dir][0][j] = tmp;
		    tmp = tmp1;
		}
		added = true;
		break;
	    }
	}

	return added;
    }

    public boolean add(int s, int r, int t, int type,
		       int dir, int comp, double score,
		       FeatureVector fv,
		       ParseForestItem p1, ParseForestItem p2) {
		
	boolean added = false;

	if(chart[s][t][dir][comp][0] == null) {
	    for(int i = 0; i < K; i++)
		chart[s][t][dir][comp][i] =
		    new ParseForestItem(s,r,t,type,dir,comp,Double.NEGATIVE_INFINITY,null,null,null);
	}

	if(chart[s][t][dir][comp][K-1].prob > score)
	    return false;
		
	for(int i = 0; i < K; i++) {
	    if(chart[s][t][dir][comp][i].prob < score) {
		ParseForestItem tmp = chart[s][t][dir][comp][i];
		chart[s][t][dir][comp][i] = new ParseForestItem(s,r,t,type,dir,comp,score,fv,p1,p2);
		for(int j = i+1; j < K && tmp.prob != Double.NEGATIVE_INFINITY; j++) {
		    ParseForestItem tmp1 = chart[s][t][dir][comp][j];
		    chart[s][t][dir][comp][j] = tmp;
		    tmp = tmp1;
		}
		added = true;
		break;
	    }

	}

	return added;
		
    }

    public double getProb(int s, int t, int dir, int comp) {
	return getProb(s,t,dir,comp,0);
    }

    public double getProb(int s, int t, int dir, int comp, int i) {
	if(chart[s][t][dir][comp][i] != null)
	    return chart[s][t][dir][comp][i].prob;
	return Double.NEGATIVE_INFINITY;
    }

    public double[] getProbs(int s, int t, int dir, int comp) {
	double[] result = new double[K];
	for(int i = 0; i < K; i++)
	    result[i] =
		chart[s][t][dir][comp][i] != null ? chart[s][t][dir][comp][i].prob : Double.NEGATIVE_INFINITY;
	return result;
    }

    public ParseForestItem getItem(int s, int t, int dir, int comp) {
	return getItem(s,t,dir,comp,0);
    }

    public ParseForestItem getItem(int s, int t, int dir, int comp, int i) {
	if(chart[s][t][dir][comp][i] != null)
	    return chart[s][t][dir][comp][i];
	return null;
    }

    public ParseForestItem[] getItems(int s, int t, int dir, int comp) {
	if(chart[s][t][dir][comp][0] != null)
	    return chart[s][t][dir][comp];
	return null;
    }

    public Object[] getBestParse() {
	Object[] d = new Object[2];
	d[0] = getFeatureVector(chart[0][end][0][0][0]);
	d[1] = getDepString(chart[0][end][0][0][0]);
	return d;
    }

    public Object[][] getBestParses() {
	Object[][] d = new Object[K][2];
	for(int k = 0; k < K; k++) {
	    if(chart[0][end][0][0][k].prob != Double.NEGATIVE_INFINITY) {
		d[k][0] = getFeatureVector(chart[0][end][0][0][k]);
		d[k][1] = getDepString(chart[0][end][0][0][k]);
	    }
	    else {
		d[k][0] = null;
		d[k][1] = null;
	    }
	}
	return d;
    }

    public FeatureVector getFeatureVector(ParseForestItem pfi) {
	if(pfi.left == null)
	    return pfi.fv;

	return cat(pfi.fv,cat(getFeatureVector(pfi.left),getFeatureVector(pfi.right)));
    }

    public String getDepString(ParseForestItem pfi) {
	if(pfi.left == null)
	    return "";

	if(pfi.dir == 0 && pfi.comp == 1)
	    return ((getDepString(pfi.left)+" "+getDepString(pfi.right)).trim()+" "+pfi.s+"|"+pfi.t+":"+pfi.type).trim();
	else if(pfi.dir == 1 && pfi.comp == 1)
	    return (pfi.t+"|"+pfi.s+":"+pfi.type+" "+(getDepString(pfi.left)+" "+getDepString(pfi.right)).trim()).trim();
	return (getDepString(pfi.left) + " " + getDepString(pfi.right)).trim();
    }
	
    public FeatureVector cat(FeatureVector fv1, FeatureVector fv2) {
	return fv1.cat(fv2);
    }

	
    // returns pairs of indeces and -1,-1 if < K pairs
    public int[][] getKBestPairs(ParseForestItem[] items1, ParseForestItem[] items2) {
	// in this case K = items1.length

	boolean[][] beenPushed = new boolean[K][K];
		
	int[][] result = new int[K][2];
	for(int i = 0; i < K; i++) {
	    result[i][0] = -1;
	    result[i][1] = -1;
	}

	BinaryHeap heap = new BinaryHeap(K+1);
	int n = 0;
	ValueIndexPair vip = new ValueIndexPair(items1[0].prob+items2[0].prob,0,0);

	heap.add(vip);
	beenPushed[0][0] = true;
		
	while(n < K) {
	    vip = heap.removeMax();
			
	    if(vip.val == Double.NEGATIVE_INFINITY)
		break;
			
	    result[n][0] = vip.i1;
	    result[n][1] = vip.i2;

	    n++;
	    if(n >= K)
		break;
			
	    if(!beenPushed[vip.i1+1][vip.i2]) {
		heap.add(new ValueIndexPair(items1[vip.i1+1].prob+items2[vip.i2].prob,vip.i1+1,vip.i2));
		beenPushed[vip.i1+1][vip.i2] = true;
	    }
	    if(!beenPushed[vip.i1][vip.i2+1]) {
		heap.add(new ValueIndexPair(items1[vip.i1].prob+items2[vip.i2+1].prob,vip.i1,vip.i2+1));
		beenPushed[vip.i1][vip.i2+1] = true;
	    }

	}
		
	return result;
    }
	
}



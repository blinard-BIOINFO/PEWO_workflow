'''
computes extended trees + AR files, which are inputs to RAPPAS db_build
this first is generally managed by RAPPAS, but separated here to facilitate analysis of very large datasets
which may generate ressource-consuming ARs (e.g., phyml requiring lots of RAM)

@author Benjamin Linard
'''

# TODO: manage phylo models parameters in phyml for AR

#configfile: "config.yaml"

import os

#debug
if (config["debug"]==1):
    print("exttree: "+os.getcwd())
#debug

#rule all:
#    input: expand(config["workdir"]+"/RAPPAS/{pruning}/AR/extended_align.phylip_phyml_ancestral_seq.txt", pruning=range(0,config["pruning_count"],1))

'''
prepare ar outputs using RAPPAS
'''
rule compute_ar_inputs:
    input:
        a=config["workdir"]+"/A/{pruning}.align",
        t=config["workdir"]+"/T/{pruning}.tree"
    output:
        config["workdir"]+"/RAPPAS/{pruning}/extended_trees/extended_align.fasta",
        config["workdir"]+"/RAPPAS/{pruning}/extended_trees/extended_align.phylip",
        config["workdir"]+"/RAPPAS/{pruning}/extended_trees/extended_tree_withBL.tree",
        config["workdir"]+"/RAPPAS/{pruning}/extended_trees/extended_tree_withBL_withoutInterLabels.tree"
    log:
        config["workdir"]+"/logs/arinputs/{pruning}.log"
    params:
        states=["nucl"] if config["states"]==0 else ["amino"],
        reduc=config["config_rappas"]["reduction"],
        workdir=config["workdir"]+"/RAPPAS/{pruning}"
    version: "1.00"
    shell:
         "java -jar RAPPAS.jar -p b -b $(which phyml) "
         "-t {input.t} -r {input.a} "
         "-w {params.workdir} -s {params.states} --ratio-reduction {params.reduc} "
         "--use_unrooted --arinputonly &> {log}"


'''
extract phylo parameters from info file to transfer them to phyml
'''
def extract_params(file):
    res={}
    with open(file,'r') as infofile:
        lines = infofile.readlines()
        for l in lines:
            if l.startswith("Substitution Matrix:") :
                res["model"]=l.split(":")[1].strip()
            if l.startswith("alpha:") :
                res["alpha"]=l.split(":")[1].strip()
    infofile.close()
    return res


rule ar:
    input:
        a=config["workdir"]+"/RAPPAS/{pruning}/extended_trees/extended_align.phylip",
        t=config["workdir"]+"/RAPPAS/{pruning}/extended_trees/extended_tree_withBL_withoutInterLabels.tree",
        s=config["workdir"]+"/T/{pruning}_optimised.info"
    output:
        config["workdir"]+"/RAPPAS/{pruning}/AR/extended_align.phylip_phyml_ancestral_seq.txt",
        config["workdir"]+"/RAPPAS/{pruning}/AR/extended_align.phylip_phyml_ancestral_tree.txt",
        config["workdir"]+"/RAPPAS/{pruning}/AR/extended_align.phylip_phyml_stats.txt",
        config["workdir"]+"/RAPPAS/{pruning}/AR/extended_align.phylip_phyml_tree.txt"
    log:
        config["workdir"]+"/logs/ar_phyml/{pruning}.log"
    params:
        outname=config["workdir"]+"/RAPPAS/{pruning}",
        c=config["phylo_params"]["categories"],
        states=["nt"] if config["states"]==0 else ["aa"],
    run:
        phylo_params=extract_params(input.s)  #launch 1 extract per pruning
        shell(
            "phyml --ancestral --no_memory_check --leave_duplicates -d {params.states} -f e -o r -b 0 -v 0.0 "
            "-i {input.a} -u {input.t} -c {params.c} "
            "-m "+phylo_params['model']+" -a "+phylo_params['alpha']+" &> {log} ;"
            """
            mv {params.outname}/extended_trees/extended_align.phylip_phyml_ancestral_seq.txt {params.outname}/AR/extended_align.phylip_phyml_ancestral_seq.txt
            mv {params.outname}/extended_trees/extended_align.phylip_phyml_ancestral_tree.txt {params.outname}/AR/extended_align.phylip_phyml_ancestral_tree.txt
            mv {params.outname}/extended_trees/extended_align.phylip_phyml_stats.txt {params.outname}/AR/extended_align.phylip_phyml_stats.txt
            mv {params.outname}/extended_trees/extended_align.phylip_phyml_tree.txt {params.outname}/AR/extended_align.phylip_phyml_tree.txt
            """
        )
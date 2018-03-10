rm(list=ls())
setwd('..')

############## data format #################
#
#    V1       V2      V3  V4 V5 V6
#1 Chr1 30403682 3738022 LG1 59  0
#
############################################

library(reshape)
library(ggplot2)

data <- read.table('valid_map.txt', header=F)
dataPlot <- data[,c(1,3,6)]
colnames(dataPlot) <- c("chr","x","y")

for (i in levels(factor(dataPlot$chr))){
	subData <- dataPlot[which(dataPlot$chr == i),]
	corr <- cor(subData$x,subData$y)
	tag = paste('rho = ',round(corr,digit=2))
	output = paste('8K_SNP.',i,'.pdf');
	p <- ggplot(data =subData, aes(x = x, y = y)) + 
	     geom_point(size=4,colour="#66CC99") + 	
         labs(x="Position on genome",y="Position on genetic map",size=8) +
		 theme(axis.title.y = element_text(size = 18)) + 
		 theme(axis.title.x = element_text(size = 18)) +
		 theme(axis.text.x = element_text(size = 14)) +
		 theme(axis.text.y = element_text(size = 14)) +
	     annotate("text", x = max(subData$x)*0.2, y = max(subData$y)*0.9, label = tag,size=10)
	pdf(file=output)
	print (p)
	dev.off() 
}


	  



processData <- function(data, times = NULL, experiments = NULL, do.normalisation=TRUE) {
  if (class(data) == "exprReslt") {
    require(puma)

    yFull <- exprs(data)
    genes <- featureNames(data)

    if (is.null(times)) {
      times <- pData(data)[,grep('time', colnames(pData(data)))]
    }

    numberOfRows <- length(genes)
    numberOfColumns <- length(colnames(exprs(data)))

    if (numberOfRows < 100) {
      warning('processData: < 100 genes in data set, turning off normalisation')
      do.normalisation <- FALSE
    }
  
    if (is.null(experiments))
      experiments <- rep(1, numberOfColumns)
  
    normalisation <- array(0, dim = c(1, numberOfColumns))

    if (do.normalisation) {
      normalisation <- colMeans(yFull)
      normalisation <- normalisation - mean(normalisation)

      ## The default operation of sweep is "-".
      yFull <- sweep(yFull, 2, normalisation)
    }

    pcts <- array(dim = c(numberOfRows, numberOfColumns, 5))

    ## Loading the percentiles 5, 25, 50, 75 and 95.
    pcts[,,1] <- prcfive(data)
    pcts[,,2] <- prctwfive(data)
    pcts[,,3] <- prcfifty(data)
    pcts[,,4] <- prcsevfive(data)
    pcts[,,5] <- prcninfive(data)

    ## normalising the percentiles
    for (i in 1:5) {
      pcts[,,i] <- sweep(pcts[,,i], 2, normalisation)
    }

    yFullVar <- array(dim = c(numberOfRows, numberOfColumns))

    for (i in 1:numberOfRows) {
      cat("Processing gene ", i, "/", numberOfRows, "\r", sep="")
      prof <- pcts[i,,]
      for (j in 1:numberOfColumns) {
        t <- .distfit(exp(prof[j, ]), 'normal')
        yFull[i, j] <- t$par[1]
        yFullVar[i, j] <- t$par[2] ^ 2
      }
    }
    cat("\n")
  
    rownames(yFullVar) <- rownames(yFull)
    colnames(yFullVar) <- colnames(yFull)
  }
  else if (class(data) == 'LumiBatch') {
    require(lumi)

    yFull <- exprs(data)
    genes <- featureNames(data)

    if (is.null(times)) {
      times <- pData(data)[,grep('time', colnames(pData(data)))]
    }

    numberOfRows <- length(genes)
    numberOfColumns <- length(colnames(exprs(data)))

    if (numberOfRows < 100) {
      warning('processData: < 100 genes in data set, turning off normalisation')
      do.normalisation <- FALSE
    }
  
    if (is.null(experiments))
      experiments <- rep(1, numberOfColumns)
  
    normalisation <- array(0, dim = c(1, numberOfColumns))

    if (do.normalisation) {
      normalisation <- colMeans(log(yFull))
      normalisation <- normalisation - mean(normalisation)

      yFull <- sweep(yFull, 2, exp(normalisation), '/')
      yFullVar <- sweep(se.exprs(data), 2, exp(normalisation), '/')
    } else {
      yFullVar <- se.exprs(data)
    }
     yFullVar <- yFullVar^2
  }
  else {
    stop("tigre:processData: Unknown data format")
  }
  
  pData <- phenoData(data)
  pData[['experiments', labelDescription='experiment ID']] <- experiments
  pData[['modeltime', labelDescription='modeltimes']] <- times
  
  return (new("ExpressionTimeSeries", exprs = yFull, var.exprs = yFullVar, 
              annotation=annotation(data), phenoData=pData,
              featureData=featureData(data),
              experimentData=experimentData(data)))
}


processRawData <- function(rawData, times, experiments=NULL, is.logged=TRUE,
                           do.normalisation=ifelse(is.logged, TRUE, FALSE)) {
  data <- rawData
  yFull <- as.matrix(data)
  genes <- rownames(data)

  numberOfRows <- length(genes)
  numberOfColumns <- length(colnames(data))

  if (is.null(experiments))
    experiments <- rep(1, numberOfColumns)
  
  # No normalisation for non-logged values for now
  if (is.logged) {
    if (do.normalisation) {
      normalisation <- colMeans(yFull)
      normalisation <- normalisation - mean(normalisation)

      # The default operation of sweep is "-".
      yFull <- sweep(yFull, 2, normalisation)
    }

    yFull <- exp(yFull)
  }
  else {
    if (do.normalisation) {
      normalisation <- colMeans(log(yFull))
      normalisation <- normalisation - mean(normalisation)

      yFull <- sweep(yFull, 2, exp(normalisation), '/')
    }
  }

  pData <- data.frame(experiments=experiments, modeltime=times)
  rownames(pData) <- colnames(data)
  metadata <- data.frame(labelDescription = c("experiment ID", "modeltimes"),
                         row.names = c("experiments", "modeltime"))
  phenoData <- new("AnnotatedDataFrame", data=pData, varMetadata=metadata)
  return (new("ExpressionTimeSeries", assayData=assayDataNew(exprs = yFull),
              phenoData=phenoData))
}

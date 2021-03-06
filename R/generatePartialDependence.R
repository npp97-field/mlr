#' @title Generate partial dependence.
#' @importFrom data.table data.table melt
#'
#' @description
#' Estimate how the learned prediction function is affected by one or more features.
#' For a learned function f(x) where x is partitioned into x_s and x_c, the partial dependence of
#' f on x_s can be summarized by averaging over x_c and setting x_s to a range of values of interest,
#' estimating E_(x_c)(f(x_s, x_c)). The conditional expectation of f at observation i is estimated similarly.
#' Additionally, partial derivatives of the marginalized function w.r.t. the features can be computed.
#'
#' @family partial_dependence
#' @family generate_plot_data
#' @aliases PartialDependenceData
#'
#' @param obj [\code{\link{WrappedModel}}]\cr
#'   Result of \code{\link{train}}.
#' @param input [\code{data.frame} | \code{\link{Task}}]\cr
#'   Input data.
#' @param features [\code{character}]\cr
#'   A vector of feature names contained in the training data.
#'   If not specified all features in the \code{input} will be used.
#' @param interaction [\code{logical(1)}]\cr
#'   Whether the \code{features} should be interacted or not. If \code{TRUE} then the Cartesian product of the
#'   prediction grid for each feature is taken, and the partial dependence at each unique combination of
#'   values of the features is estimated. Note that if the length of \code{features} is greater than two,
#'   \code{\link{plotPartialDependence}} and \code{\link{plotPartialDependenceGGVIS}} cannot be used.
#'   If \code{FALSE} each feature is considered separately. In this case \code{features} can be much longer
#'   than two.
#'   Default is \code{FALSE}.
#' @param derivative [\code{logical(1)}]\cr
#'   Whether or not the partial derivative of the learned function with respect to the features should be
#'   estimated. If \code{TRUE} \code{interaction} must be \code{FALSE}. The partial derivative of individual
#'   observations may be estimated. Note that computation time increases as the learned prediction function
#'   is evaluated at \code{gridsize} points * the number of points required to estimate the partial derivative.
#'   Additional arguments may be passed to \code{\link[numDeriv]{grad}} (for regression or survival tasks) or
#'   \code{\link[numDeriv]{jacobian}} (for classification tasks). Note that functions which are not smooth may
#'   result in estimated derivatives of 0 (for points where the function does not change within +/- epsilon)
#'   or estimates trending towards +/- infinity (at discontinuities).
#'   Default is \code{FALSE}.
#' @param individual [\code{logical(1)}]\cr
#'   Whether to plot the individual conditional expectation curves rather than the aggregated curve, i.e.,
#'   rather than aggregating (using \code{fun}) the partial dependences of \code{features}, plot the
#'   partial dependences of all observations in \code{data} across all values of the \code{features}.
#'   The algorithm is developed in Goldstein, Kapelner, Bleich, and Pitkin (2015).
#'   Default is \code{FALSE}.
#' @param fun [\code{function}]\cr
#'
#'   A function which operates on the output on the predictions made on the \code{input} data. For regression
#'   this means a numeric vector, and, e.g., for a multiclass classification problem, this migh instead be probabilities
#'   which are returned as a numeric matrix. This argument can return vectors of arbitrary length, however,
#'   if their length is greater than one, they must by named, e.g., \code{fun = mean} or
#'   \code{fun = function(x) c("mean" = mean(x), "variance" = var(x))}.
#'   The default is the mean, unless \code{obj} is classification with \code{predict.type = "response"}
#'   in which case the default is the proportion of observations predicted to be in each class.
#' @param bounds [\code{numeric(2)}]\cr
#'   The value (lower, upper) the estimated standard error is multiplied by to estimate the bound on a
#'   confidence region for a partial dependence. Ignored if \code{predict.type != "se"} for the learner.
#'   Default is the 2.5 and 97.5 quantiles (-1.96, 1.96) of the Gaussian distribution.
#' @param uniform [\code{logical(1)}]\cr
#'   Whether or not the prediction grid for the \code{features} is a uniform grid of size \code{n[1]} or sampled with
#'   replacement from the \code{input}.
#'   Default is \code{TRUE}.
#' @param n [\code{integer21)}]\cr
#'   The first element of \code{n} gives the size of the prediction grid created for each feature.
#'   The second element of \code{n} gives the size of the sample to be drawn without replacement from the \code{input} data.
#'   Setting \code{n[2]} less than the number of rows in the \code{input} will decrease computation time.
#'   The default for \code{n[1]} is 10, and the default for \code{n[2]} is the number of rows in the \code{input}.
#' @param ... additional arguments to be passed to \code{\link[mmpf]{marginalPrediction}}.
#' @return [\code{PartialDependenceData}]. A named list, which contains the partial dependence,
#'   input data, target, features, task description, and other arguments controlling the type of
#'   partial dependences made.
#'
#' Object members:
#'   \item{data}{[\code{data.frame}]\cr
#'     Has columns for the prediction: one column for regression and
#'     survival analysis, and a column for class and the predicted probability for classification as well
#'     as a a column for each element of \code{features}. If \code{individual = TRUE} then there is an
#'     additional column \code{idx} which gives the index of the \code{data} that each prediction corresponds to.}
#'   \item{task.desc}{[\code{\link{TaskDesc}}]\cr
#'     Task description.}
#'   \item{target}{Target feature for regression, target feature levels for classification,
#'         survival and event indicator for survival.}
#'   \item{features}{[\code{character}]\cr
#'     Features argument input.}
#'   \item{interaction}{[\code{logical(1)}]\cr
#'     Whether or not the features were interacted (i.e. conditioning).}
#'   \item{derivative}{[\code{logical(1)}]\cr
#'     Whether or not the partial derivative was estimated.}
#'   \item{individual}{[\code{logical(1)}]\cr
#'     Whether the partial dependences were aggregated or the individual curves are retained.}
#' @references
#' Goldstein, Alex, Adam Kapelner, Justin Bleich, and Emil Pitkin. \dQuote{Peeking inside the black box: Visualizing statistical learning with plots of individual conditional expectation.} Journal of Computational and Graphical Statistics. Vol. 24, No. 1 (2015): 44-65.
#'
#' Friedman, Jerome. \dQuote{Greedy Function Approximation: A Gradient Boosting Machine.} The Annals of Statistics. Vol. 29. No. 5 (2001): 1189-1232.
#' @examples
#' lrn = makeLearner("regr.svm")
#' fit = train(lrn, bh.task)
#' pd = generatePartialDependenceData(fit, bh.task, "lstat")
#' plotPartialDependence(pd, data = getTaskData(bh.task))
#'
#' lrn = makeLearner("classif.rpart", predict.type = "prob")
#' fit = train(lrn, iris.task)
#' pd = generatePartialDependenceData(fit, iris.task, "Petal.Width")
#' plotPartialDependence(pd, data = getTaskData(iris.task))
#' @export
generatePartialDependenceData = function(obj, input, features,
  interaction = FALSE, derivative = FALSE, individual = FALSE,
  fun = mean, bounds = c(qnorm(.025), qnorm(.975)),
  uniform = TRUE, n = c(10, NA), ...) {

  requirePackages("mmpf")
  assertClass(obj, "WrappedModel")
  if (obj$learner$predict.type == "se" & individual)
    stop("individual = TRUE not compatabile with predict.type = 'se'!")
  if (obj$learner$predict.type == "se" & derivative)
    stop("derivative = TRUE is not compatible with predict.type = 'se'!")
  if (!inherits(input, c("Task", "data.frame")))
    stop("input must be a Task or a data.frame!")
  if (inherits(input, "Task")) {
    data = getTaskData(input)
    td = input$task.desc
  } else {
    data = input
    td = obj$task.desc
    assertDataFrame(data, col.names = "unique", min.rows = 1L, min.cols = length(obj$features) + length(td$target))
    assertSetEqual(colnames(data), c(obj$features, td$target), ordered = FALSE)
  }

  if (is.na(n[2]))
    n[2] = nrow(data)

  if (missing(features))
    features = colnames(data)[!colnames(data) %in% td$target]
  else
    assertSubset(features, obj$features)

  assertFlag(interaction)
  assertFlag(derivative)
  if (derivative & interaction)
    stop("interaction cannot be TRUE if derivative is TRUE.")
  if (derivative) {
    if (any(sapply(data[, features, drop = FALSE], class) %in% c("factor", "ordered", "character")))
      stop("All features must be numeric to estimate set derivative = TRUE!")
  }

  se = Function = Class = patterns = NULL # nolint

  assertFlag(individual)
  if (individual)
    fun = identity

  assertFunction(fun)
  test.fun = fun(1:3)
  if (length(test.fun) == 1L) {
    multi.fun = FALSE
  } else {
    multi.fun = TRUE
    if (is.null(names(test.fun)) & !individual)
      stop("If fun returns a vector it must be named.")
  }

  assertNumeric(bounds, len = 2L)
  assertNumber(bounds[1], upper = 0)
  assertNumber(bounds[2], lower = 0)
  assertFlag(uniform)
  assertCount(n[1], positive = TRUE)
  assertCount(n[2], positive = TRUE)
  if (n[2] > nrow(data))
    stop("The number of points taken from the training data cannot exceed the number of training data points.")

  if (td$type == "regr")
    target = td$target
  else if (td$type == "classif") {
    if (length(td$class.levels) > 2L)
      target = td$class.levels
    else
      target = td$positive
  } else
    target = "Risk"

  if (!derivative) {
    args = list(model = obj, data = data, uniform = uniform, aggregate.fun = fun,
      predict.fun = getPrediction, n = n, ...)
    out = parallelMap(mmpf::marginalPrediction,
      vars = if (interaction) list(features) else as.list(features), more.args = args)
    if (length(target) == 1L) {
      out = lapply(out, function(x) {
        feature = features[features %in% names(x)]
          names(x) = stri_replace_all(names(x), target, regex = "^preds")
          x = data.table(x)
          if (individual) {
            x = melt(x, id.vars = feature, variable.name = "n", value.name = target)
            x[, n := stri_replace(n, "", regex = target)]
            setnames(x, c(feature, if (individual) "n" else "Function", target), names(x))
          } else {
            x
          }
        })
    }
  } else {
    points = lapply(features, function(x) mmpf::uniformGrid(data[[x]], n[1]))
    names(points) = features
    args = list(obj = obj, data = data, uniform = uniform, fun = fun,
      n = n, points = points, target = target, individual = individual, ...)
    if (individual) {
      int.points = sample(seq_len(nrow(data)), n[2])
      out = parallelMap(doDerivativeMarginalPrediction, x = features,
        z = int.points, more.args = args)
    } else {
      out = parallelMap(doDerivativeMarginalPrediction, x = features, more.args = args)
    }
  }
  out = rbindlist(out, fill = TRUE)

  if (length(target) == 1L) {
    if (!multi.fun) {
      setcolorder(out, c(names(out)[grepl(paste(target, "preds", sep = "|"),
        names(out))], if (obj$learner$predict.type == "se") "se" else NULL, features))
      setnames(out, names(out), c(target, if (obj$learner$predict.type == "se") "se" else NULL, features))
    } else if (individual) {
      setcolorder(out, c(target, "n", features))
    } else {
      setnames(out, names(out), stri_replace_all_fixed(names(out), "preds", ""))
      out = melt(out, id.vars = features, variable.name = "Function",
        value.name = target)
      setcolorder(out, c(target, "Function", features))
    }
  } else {
    if (!multi.fun) {
      out = melt(out, measure.vars = target,
        variable.name = if (td$type == "classif") "Class" else "Function",
        value.name = if (td$type == "classif") "Probability" else "Prediction")
      if (td$type == "classif") {
        out[, Class := stri_replace_all_regex(Class, "^prob\\.", "")]
        setcolorder(out, c("Class",
          if (td$type == "classif") "Probability" else "Prediction", features))
      } else {
        out[, Function := stri_replace_all_regex(target, "^preds\\.", "")]
        setcolorder(out, c("Function",
          if (td$type == "classif") "Probability" else "Prediction", features))
      }
    } else if (individual) {
      if (!derivative)
        out = melt(out, measure = patterns(target), variable.name = "n",
          value.name = target)
      out = melt(out, measure.vars = target,
        variable.name = if (td$type == "classif") "Class" else "Target",
        value.name = if (td$type == "classif") "Probability" else "Prediction")
      setcolorder(out, c(if (td$type == "classif") "Class" else "Target",
        if (td$type == "classif") "Probability" else "Prediction", "n", features))
    } else {
      out = melt(out, id.vars = c(features, if (individual) "n"),
        variable.name = if (td$type == "classif") "Class" else "Function",
        value.name = if (td$type == "classif") "Probability" else "Prediction")
      if (td$type == "classif") {
        x = stri_split_regex(out$Class, "\\.", n = 2, simplify = TRUE)
        ## checking to see if there is detritus, e.g., preds.class or something
        id = apply(x, 2, function(z) length(unique(z)) > 1L)
        if (!all(id)) {
          out[, "Class"] = x[, id]
          setcolorder(out, c("Class", "Probability", features))
        } else {
          out[, c("Class", "Function") := lapply(1:2, function(i) x[, i])]
          out[, Function := stri_replace_all_regex(Function, "^preds\\.", "")]
          setcolorder(out, c("Class", "Function", "Probability", features))
        }
      } else {
        out[, Function := stri_replace_all_regex(Function, "^preds\\.", "")]
        setcolorder(out, c("Class", "Function", "Prediction", features))
      }
    }
  }

  # for se, compute upper and lower bounds
  if (obj$learner$predict.type == "se") {
    x = outer(out$se, bounds) + out[[target]]
    out[, c("lower", "upper") := lapply(1:2, function(i) x[, i])]
    out[, se := NULL]
    target = c("lower", target, "upper")
    setcolorder(out, c(target, features))
  }

  makeS3Obj("PartialDependenceData",
    data = out,
    task.desc = td,
    target = target,
    features = features,
    derivative = derivative,
    interaction = interaction,
    individual = individual)
}

## second layer wrapper for numDeriv grad and jacobian use with marginal prediction
doDerivativeMarginalPrediction = function(x, z = sample(seq_len(nrow(data)), n[2]),
  target, points, obj, data, uniform, fun, n, individual, ...) {

  if (length(target) == 1L) {
    ret = cbind(numDeriv::grad(numDerivWrapper,
      x = points[[x]], model = obj, data = data,
      uniform = uniform, aggregate.fun = fun, vars = x,
      int.points = z,
      predict.fun = getPrediction, n = n, target = target,
      individual = individual, ...),
      points[[x]], if (individual) z)
  } else {
    out = lapply(points[[x]], function(x.value) {
      t(numDeriv::jacobian(numDerivWrapper, x = x.value, model = obj, data = data,
        uniform = uniform, aggregate.fun = fun, vars = x, int.points = z,
        predict.fun = getPrediction, n = n, target = target,
        individual = individual, ...))
    })
    out = do.call("rbind", out)
    ret = cbind(out, points[[x]], if (individual) z)
  }
  ret = as.data.table(ret)
  setnames(ret, names(ret), c(target, x, if (individual) "n"))
  ret
}


# grad and jacobian both need to take a vector along with ...
# and they return either a vector or a matrix
# so i need to pass the points as that x, and then extract the appropriate
# vector or matrix from marginalPrediction
numDerivWrapper = function(points, vars, individual, target, ...) {
  args = list(...)
  args$points = list(points)
  names(args$points) = vars
  args$vars = vars
  out = do.call(mmpf::marginalPrediction, args)
  as.matrix(out[, which(names(out) != vars), with = FALSE])
}

#' @export
print.PartialDependenceData = function(x, ...) {
  catf("PartialDependenceData")
  catf("Task: %s", x$task.desc$id)
  catf("Features: %s", stri_paste(x$features, collapse = ", ", sep = " "))
  catf("Target: %s", stri_paste(x$target, collapse = ", ", sep = " "))
  catf("Derivative: %s", x$derivative)
  catf("Interaction: %s", x$interaction)
  catf("Individual: %s", x$individual)
  printHead(x$data, ...)
}
#' @title Plot a partial dependence with ggplot2.
#' @description
#' Plot a partial dependence from \code{\link{generatePartialDependenceData}} using ggplot2.
#'
#' @family partial_dependence
#' @family plot
#'
#' @param obj [\code{PartialDependenceData}]\cr
#'   Generated by \code{\link{generatePartialDependenceData}}.
#' @param geom [\code{charater(1)}]\cr
#'   The type of geom to use to display the data. Can be \dQuote{line} or \dQuote{tile}.
#'   For tiling at least two features must be used with \code{interaction = TRUE} in the call to
#'   \code{\link{generatePartialDependenceData}}. This may be used in conjuction with the
#'   \code{facet} argument if three features are specified in the call to
#'   \code{\link{generatePartialDependenceData}}.
#'   Default is \dQuote{line}.
#' @param facet [\code{character(1)}]\cr
#'   The name of a feature to be used for facetting.
#'   This feature must have been an element of the \code{features} argument to
#'   \code{\link{generatePartialDependenceData}} and is only applicable when said argument had length
#'   greater than 1.
#'   The feature must be a factor or an integer.
#'   If \code{\link{generatePartialDependenceData}} is called with the \code{interaction} argument \code{FALSE}
#'   (the default) with argument \code{features} of length greater than one, then \code{facet} is ignored and
#'   each feature is plotted in its own facet.
#'   Default is \code{NULL}.
#' @template arg_facet_nrow_ncol
#' @param p [\code{numeric(1)}]\cr
#'   If \code{individual = TRUE} then \code{sample} allows the user to sample without replacement
#'   from the output to make the display more readable. Each row is sampled with probability \code{p}.
#'   Default is \code{1}.
#' @param data [\code{data.frame}]\cr
#'   Data points to plot. Usually the training data. For survival and binary classification tasks a rug plot
#'   wherein ticks represent failures or instances of the positive class are shown. For regression tasks
#'   points are shown. For multiclass classification tasks ticks are shown and colored according to their class.
#'   Both the features and the target must be included.
#'   Default is \code{NULL}.
#' @template ret_gg2
#' @export
plotPartialDependence = function(obj, geom = "line", facet = NULL, facet.wrap.nrow = NULL,
  facet.wrap.ncol = NULL, p = 1, data = NULL) {

  assertClass(obj, "PartialDependenceData")
  assertChoice(geom, c("tile", "line"))
  if (obj$interaction & length(obj$features) > 2L & geom != "tile")
    stop("Cannot plot more than 2 features together with line plots.")
  if (geom == "tile") {
    if (!obj$interaction)
      stop("obj argument created by generatePartialDependenceData was called with interaction = FALSE!")
  }

  if ("FunctionalANOVAData" %in% class(obj)) {
    if (length(unique(obj$data$effect)) > 1L & obj$interaction)
      stop("Cannot plot multiple ANOVA effects of depth > 1.")
  }

  if (!is.null(data)) {
    assertDataFrame(data, col.names = "unique", min.rows = 1L,
                    min.cols = length(obj$features) + length(obj$td$target))
    assertSubset(obj$features, colnames(data), empty.ok = FALSE)
  }

  if (!is.null(facet)) {
    assertChoice(facet, obj$features)
    if (!length(obj$features) %in% 2:3)
      stop("obj argument created by generatePartialDependenceData must be called with two or three features to use this argument!")
    if (!obj$interaction)
      stop("obj argument created by generatePartialDependenceData must be called with interaction = TRUE to use this argument!")

    features = obj$features[which(obj$features != facet)]
    if (is.factor(obj$data[[facet]])) {
      obj$data[[facet]] = stri_paste(facet, "=", obj$data[[facet]], sep = " ")
    } else if (is.character(obj$data[[facet]])) {
      obj$data[[facet]] = stri_paste(facet, "=", as.factor(obj$data[[facet]]), sep = " ")
    } else if (is.numeric(obj$data[[facet]])) {
      obj$data[[facet]] = stri_paste(facet, "=", as.factor(signif(obj$data[[facet]], 3L)), sep = " ")
    } else {
      stop("Invalid input to facet arg. Must refer to a numeric/integer, character, or facet feature.")
    }

    scales = "fixed"
  } else {
    features = obj$features
    if (length(features) > 1L & !(length(features) == 2L & geom == "tile")) {
      facet = "Feature"
      scales = "free_x"
    } else {
      scales = "fixed"
    }
  }

  # detect if there was a multi-output function used in which case
  # there should be a column named function which needs to be facetted
  if ("Function" %in% colnames(obj$data)) {
      facet = c(facet, "Function")
  }

  # sample from individual partial dependence estimates
  if (p != 1) {
    assertNumber(p, lower = 0, upper = 1, finite = TRUE)
    if (!obj$individual)
      stop("obj argument created by generatePartialDependenceData must be called with individual = TRUE to use this argument!")
    rows = unique(obj$data$idx)
    id = sample(rows, size = floor(p * length(rows)))
    obj$data = obj$data[which(obj$data$idx %in% id), ]
  }

  if (obj$task.desc$type %in% c("regr", "classif"))
    target = obj$task.desc$target
  else
    target = "Risk"

  # are there bounds compatible with a ribbon plot?
  bounds = all(c("lower", "upper") %in% colnames(obj$data) & obj$task.desc$type %in% c("surv", "regr") &
    length(features) < 3L & geom == "line")

  if (geom == "line") {
    # find factors and cast them to numerics so that we can melt
    idx = which(sapply(obj$data, class) == "factor" & colnames(obj$data) %in% features)
    # explicit casting previously done implicitly by reshape2::melt.data.frame
    for (id in idx) obj$data[, id] = as.numeric(obj$data[[id]])

    # melt the features but leave everything else alone
    obj$data = setDF(melt(data.table(obj$data),
      id.vars = colnames(obj$data)[!colnames(obj$data) %in% features],
      variable = "Feature", value.name = "Value", na.rm = TRUE, variable.factor = TRUE))

    # when individual is false plot variable value against the target
    if (!obj$individual) {
      # for regression/survival this is a simple line plot
      if (obj$task.desc$type %in% c("regr", "surv"))
        plt = ggplot(obj$data, aes_string("Value", target)) +
          geom_line(color = ifelse(is.null(data), "black", "red")) + geom_point()
      else # for classification create different colored lines
        plt = ggplot(obj$data, aes_string("Value", "Probability", group = "Class", color = "Class")) +
          geom_line() + geom_point()
    } else { # if individual is true make the lines semi-transparent
      if (obj$task.desc$type %in% c("regr", "surv")) {
        plt = ggplot(obj$data, aes_string("Value", target, group = "n")) +
          geom_line(alpha = .25, color = ifelse(is.null(data), "black", "red")) + geom_point()
      } else {
        plt = ggplot(obj$data, aes_string("Value", "Probability", group = "idx", color = "Class")) +
          geom_line(alpha = .25) + geom_point()
      }
    }

    # if there is only one feature than melting was redundant (but cleaner code)
    # so rename the x-axis using the feature name. rename target only if it was a vector
    # since in this case the target name isn't passed through
    if (length(features) == 1L) {
      if (obj$task.desc$type %in% c("regr", "surv"))
        plt = plt + labs(x = features, y = target)
      else
        plt = plt + labs(x = features)
    }

    # ribbon bounds from se estimation
    if (bounds)
      plt = plt + geom_ribbon(aes_string(ymin = "lower", ymax = "upper"), alpha = .5)

    # labels added to for derivative plots
    if (obj$derivative)
      plt = plt + ylab(stri_paste(target, "(derivative)", sep = " "))

  } else { ## tiling
    if (obj$task.desc$type == "classif") {
      target = "Probability"
      facet = "Class"
      if ("Function" %in% obj$data)
        facet = c(facet, "Function")
      scales = "free"
    }
    plt = ggplot(obj$data, aes_string(x = features[1], y = features[2], fill = target))
    plt = plt + geom_raster(aes_string(fill = target))

    # labels for ICE plots
    if (obj$derivative)
      plt = plt + scale_fill_continuous(guide = guide_colorbar(title = stri_paste(target, "(derivative)", sep = " ")))
  }

  # facetting which is either passed in by the user, the features column when interaction = FALSE and length(features) > 1
  # and/or when fun outputs a vector (then facetting on the Function column)
  if (!is.null(facet)) {
    if (length(facet) == 1L)
      plt = plt + facet_wrap(as.formula(stri_paste("~", facet)), scales = scales,
        nrow = facet.wrap.nrow, ncol = facet.wrap.ncol)
    else
      plt = plt + facet_wrap(as.formula(stri_paste(facet[2], "~", facet[1])), scales = scales,
        nrow = facet.wrap.nrow, ncol = facet.wrap.ncol) # facet ordering is reversed deliberately to handle len = 1 case!
  }

  # data overplotting
  if (!is.null(data)) {
    data = data[, colnames(data) %in% c(obj$features, obj$task.desc$target)]
    if (!is.null(facet)) {
      feature.facet = facet[facet %in% obj$features]
      fun.facet = facet[!facet %in% feature.facet]

      if (length(fun.facet) > 0L && (fun.facet == "Feature" || !feature.facet %in% obj$features))
        data = melt(data, id.vars = c(obj$task.desc$target, feature.facet),
          variable = "Feature", value.name = "Value", na.rm = TRUE, variable.factor = TRUE)

      if (length(feature.facet) > 0) {
        if (!is.factor(data[[feature.facet]]))
          data[[feature.facet]] = stri_paste(feature.facet, "=", as.factor(signif(data[[feature.facet]], 2)), sep = " ")
        else
          data[[feature.facet]] = stri_paste(feature.facet, "=", data[[feature.facet]], sep = " ")
      }

      if (length(fun.facet) > 0L && "Function" %in% fun.facet) {
        data = mmpf::cartesianExpand(data, data.frame("Function" = unique(obj$data$Function)))
      }
    }

    if (geom == "line") {
      if (obj$task.desc$type %in% c("classif", "surv")) {
        if (obj$task.desc$type == "classif") {
          if (!is.na(obj$task.desc$positive)) {
            plt = plt + geom_rug(aes_string(plt$labels$x, color = obj$task.desc$target),
                                 data[data[[obj$task.desc$target]] == obj$task.desc$positive, ],
                                 alpha = .25, inherit.aes = FALSE)
          } else {
            plt = plt + geom_rug(aes_string(plt$labels$x), data, alpha = .25, inherit.aes = FALSE)
          }
        } else {
          plt = plt + geom_rug(aes_string(plt$labels$x),
                               data[data[[obj$task.desc$target[2]]], ],
                               alpha = .25, inherit.aes = FALSE)
        }
      } else {
        plt = plt + geom_point(aes_string(plt$labels$x, obj$task.desc$target),
                               data, alpha = .25, inherit.aes = FALSE)
      }
    } else {
      plt = plt + geom_point(aes_string(plt$labels$x, plt$labels$y), data, alpha = .25, inherit.aes = FALSE)
    }
  }

  plt
}



#' @title Plot a partial dependence using ggvis.
#' @description
#' Plot partial dependence from \code{\link{generatePartialDependenceData}} using ggvis.
#'
#' @family partial_dependence
#' @family plot
#'
#' @param obj [\code{PartialDependenceData}]\cr
#'   Generated by \code{\link{generatePartialDependenceData}}.
#' @param interact [\code{character(1)}]\cr
#'   The name of a feature to be mapped to an interactive sidebar using Shiny.
#'   This feature must have been an element of the \code{features} argument to
#'   \code{\link{generatePartialDependenceData}} and is only applicable when said argument had length
#'   greater than 1.
#'   If \code{\link{generatePartialDependenceData}} is called with the \code{interaction} argument \code{FALSE}
#'   (the default) with argument \code{features} of length greater than one, then \code{interact} is ignored and
#'   the feature displayed is controlled by an interactive side panel.
#'   Default is \code{NULL}.
#' @param p [\code{numeric(1)}]\cr
#'   If \code{individual = TRUE} then \code{sample} allows the user to sample without replacement
#'   from the output to make the display more readable. Each row is sampled with probability \code{p}.
#'   Default is \code{1}.
#' @template ret_ggv
#' @export
plotPartialDependenceGGVIS = function(obj, interact = NULL, p = 1) {
  requirePackages("_ggvis")
  assertClass(obj, "PartialDependenceData")
  .Deprecated("plotPartialDependence")

  if (!is.null(interact))
    assertChoice(interact, obj$features)
  if (obj$interaction & length(obj$features) > 2L)
    stop("It is only possible to plot 2 features with this function.")

  if (!obj$interaction & !is.null(interact))
    stop("obj argument created by generatePartialDependenceData was called with interaction = FALSE!")

  if (p != 1) {
    assertNumber(p, lower = 0, upper = 1, finite = TRUE)
    if (!obj$individual)
      stop("obj argument created by generatePartialDependenceData must be called with individual = TRUE to use this argument!")
    rows = unique(obj$data$idx)
    id = sample(rows, size = floor(p * length(rows)))
    obj$data = obj$data[which(obj$data$idx %in% id), ]
  }

  if (obj$interaction & length(obj$features) == 2L) {
    if (is.null(interact))
      interact = obj$features[-which.max(sapply(obj$features, function(x) length(unique(obj$data[[x]]))))]
    x = obj$features[which(obj$features != interact)]
    if (is.factor(obj$data[[interact]]))
      choices = levels(obj$data[[interact]])
    else
      choices = sort(unique(obj$data[[interact]]))
  } else if (!obj$interaction & length(obj$features) > 1L) {
    id = colnames(obj$data)[!colnames(obj$data) %in% obj$features]
    obj$data = melt(obj$data, id.vars = id, variable.name = "Feature",
                    value.name = "Value", na.rm = TRUE, variable.factor = TRUE)
    interact = "Feature"
    choices = obj$features
  } else
    interact = NULL

  bounds = all(c("lower", "upper") %in% colnames(obj$data) & obj$task.desc$type %in% c("surv", "regr"))

  if (obj$task.desc$type %in% c("regr", "classif"))
    target = obj$task.desc$target
  else
    target = "Risk"

  createPlot = function(td, target, interaction, individual, data, x, bounds) {
    classif = td$type == "classif" & all(target %in% td$class.levels)
    if (classif) {
      if (interaction)
        plt = ggvis::ggvis(data,
          ggvis::prop("x", as.name(x)),
          ggvis::prop("y", as.name("Probability")),
          ggvis::prop("stroke", as.name("Class")))
      else if (!interaction & !is.null(interact)) ## no interaction but multiple features
        plt = ggvis::ggvis(data,
          ggvis::prop("x", as.name("Value")),
          ggvis::prop("y", as.name("Probability")),
          ggvis::prop("stroke", as.name("Class")))
      else
        plt = ggvis::ggvis(data,
          ggvis::prop("x", as.name(x)),
          ggvis::prop("y", as.name("Probability")),
          ggvis::prop("stroke", as.name("Class")))

    } else { ## regression/survival
      if (interaction)
        plt = ggvis::ggvis(data,
          ggvis::prop("x", as.name(x)),
          ggvis::prop("y", as.name(target)))
      else if (!interaction & !is.null(interact))
        plt = ggvis::ggvis(data,
          ggvis::prop("x", as.name("Value")),
          ggvis::prop("y", as.name(target)))
      else
        plt = ggvis::ggvis(data,
          ggvis::prop("x", as.name(x)),
          ggvis::prop("y", as.name(target)))
    }

    if (bounds)
      plt = ggvis::layer_ribbons(plt,
        ggvis::prop("y", as.name("lower")),
        ggvis::prop("y2", as.name("upper")),
        ggvis::prop("opacity", .5))
    if (individual) {
      plt = ggvis::group_by_.ggvis(plt, as.name("idx"))
      plt = ggvis::layer_paths(plt, ggvis::prop("opacity", .25))
    } else {
      if (classif)
        plt = ggvis::layer_points(plt, ggvis::prop("fill", as.name("Class")))
      else
        plt = ggvis::layer_points(plt)
      plt = ggvis::layer_lines(plt)
    }

    plt
  }

if (obj$derivative)
    header = stri_paste(target, "(derivative)", sep = " ")
  else
    header = target

  if (!is.null(interact)) {
    requirePackages("_shiny")
    panel = shiny::selectInput("interaction_select", interact, choices)
    ui = shiny::shinyUI(
      shiny::pageWithSidebar(
        shiny::headerPanel(header),
        shiny::sidebarPanel(panel),
        shiny::mainPanel(
          shiny::uiOutput("ggvis_ui"),
          ggvis::ggvisOutput("ggvis")
        )
      ))
    server = shiny::shinyServer(function(input, output) {
      plt = shiny::reactive(createPlot(obj$task.desc, obj$target, obj$interaction, obj$individual,
          obj$data[obj$data[[interact]] == input$interaction_select, ],
          x, bounds))
      ggvis::bind_shiny(plt, "ggvis", "ggvis_ui")
      })
    shiny::shinyApp(ui, server)
  } else
    createPlot(obj$task.desc, obj$target, obj$interaction, obj$individual, obj$data, obj$features, bounds)
}

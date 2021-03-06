#' Random Sampling of 1-dim. Mixtures of Normal Distribution
#' 
#' Set sample size n and parameters of MixtNormal(mu,sigma,pi).
#' By definition, dimension of mu, sigma and pi must be the same.
#' In the function, parameter `pi` is normalized.
#' @param n <int scalar> : sample size
#' @param mu <double vector> : population means
#' @param sigma <double vector> : population sds
#' @param ratio <double vector> : mixtured ratio
#' @return The output will be <double vector> of size n that you input.
#' 
#' @importFrom dplyr %>%
#' @importFrom purrr pmap_dbl
#' @importFrom stats rnorm
#' @export 
#' 
random_mixt_normal <- function(n, mu, sigma, ratio){
  # 1. Preliminaries and Error Corrections
  # record a number of components from dimension of the parameter `mu`
  n_components <- length(mu)
  ratio <- ratio / sum(ratio)
  # sanity check for dimension of parameters
  if (length(sigma) != n_components | length(ratio) != n_components){
    stop("Error : dimension of mu, sigma and ratio must be the same.")
  }
  if (prod(sigma > 0) != 1){
    stop("Error : sigma is not positive.")
  }
  # 2. Main Calculation
  # decide a component that each point is sampled...
  component_idx <- sample(x = 1:n_components, size = n, prob = ratio, replace = TRUE)
  # sampling
  obj <- list(component_idx = component_idx) %>%
    pmap_dbl(.f = function(component_idx){
      rnorm(1, mean = mu[component_idx], sd = sigma[component_idx])
      })
  # 3. output
  return(obj)
}





#' Probability Density Function of 1-dim. Mixtures of Normal Distribution
#' 
#' Set sample point x and parameters of MixtNormal(mu,sigma,pi).
#' By definition, dimension of mu, sigma and pi must be the same.
#' In the function, parameter `pi` is normalized.
#' @param x <double vector> : sample point
#' @param mu <double vector> : population means
#' @param sigma <double vector> : population sd
#' @param ratio <double vector> : mixtured ratio
#' @return The output is <tibble> that is probability densities of each saple point at each component and mixture distribution.
#'
#' @importFrom dplyr %>%
#' @importFrom dplyr as_tibble
#' @importFrom dplyr mutate
#' @importFrom dplyr select
#' @importFrom dplyr filter
#' @importFrom dplyr everything
#' @importFrom purrr map
#' @importFrom stringr str_c
#' @importFrom stats dnorm
#' @export
#' 
density_mixt_normal <- function(x, mu, sigma, ratio){
  # 1. Preliminaries and Error Correction
  # number of componets calculated by dimension of parameter `mu`
  n_components <- length(mu)
  ratio <- ratio / sum(ratio)
  # sanity check of each parameter's dimension
  if (length(sigma) != n_components | length(ratio) != n_components){
    stop("Error : dimension of mu, sigma and ratio must be the same.")
  }
  if (prod(sigma > 0) != 1){
    stop("Error : sigma is not positive.")
  }
  # 2. Main Calculation
  # calculation of probability density
  # pd_each_component : output matrix is probability densities of each component
  # pd : output vector is probability density
  pd_each_component <- as.list(x) %>%
    map(.f = ~dnorm(., mean = mu, sd = sigma)) %>%
    unlist() %>%
    matrix(byrow = TRUE, ncol = n_components)
  colnames(pd_each_component) <- str_c("component_", 1:n_components)
  pd <- as.numeric(pd_each_component %*% ratio)
  # 3. output
  obj <- as_tibble(pd_each_component)
  obj <- obj %>%
    mutate(prob_density = pd, x = x) %>%
    select(x, prob_density, everything())
  return(obj)
}





#' Log Likelihood of 1-dim. Mixtures of Normal Distribution
#' 
#' @param x <double vector> : sample point
#' @param mu <double vector> : population means
#' @param sigma <double vector> : population sd
#' @param ratio <double vector> : mixtured ratio
#' @return The output is <double vector> that is loglikelihood of each point of x 
#' 
#' @importFrom dplyr %>%
#' @export
#' 
LL_mixt_normal <- function(x, mu, sigma, ratio){
  # 1. Preliminaries and Error Correction
  # number of components calculated from dimension of mu
  n_components <- length(mu)
  # sanity check
  if (length(sigma) != n_components | length(ratio) != n_components){
    stop("Error : dimension of mu, sigma and ratio must be the same.")
  }
  if (prod(sigma > 0) != 1){
    stop("Error : sigma is not positive.")
  }
  # 2. Main Calculation
  # calculation of log likelihood
  obj <- sum(log(density_mixt_normal(x, mu = mu, sigma = sigma, ratio = ratio)$prob_density))
  # output
  return(obj)
}





#' EM Algorithm for 1-dim. Mixtures of Normal Distribution
#' 
#' @param x <double vector> : sample
#' @param max_iter <int scalar> : maximum number of iterations
#' @param tol <double scalar> : tolerance
#' @param init_mu <double vector> : initial values of population means
#' @param init_sigma <double vector> : initial values of population sds
#' @param init_ratio <double vector> : initial values of population ratio
#' @return The output is the set (MLE of params, LL, estimated component of each sample point, n_iter).
#' 
#' @importFrom dplyr tibble
#' @importFrom dplyr select
#' @importFrom dplyr bind_rows
#' @importFrom purrr map2_df
#' @importFrom purrr map_chr
#' @importFrom rlang .data
#' @export
#' 
EM_mixt_normal <- function(x, max_iter, tol, init_mu, init_sigma, init_ratio){
  # 1. Preliminalies and Error Correction
  # number of components and sample size
  sample_size <- length(x)    # sample size
  n_components <- length(init_mu)
  init_ratio <- init_ratio / sum(init_ratio)
  # sanity check for dimension of parameters
  if (length(init_sigma) != n_components | length(init_ratio) != n_components){
    stop("Error : dimension of mu, sigma and ratio must be the same.")
  }
  if (prod(init_sigma > 0) != 1){
    stop("Error : init_sigma is not positive.")
  }
  # 2. Main Calculation
  # settings of initial values
  mu <- init_mu; sigma <- init_sigma; ratio <- init_ratio
  # history
  LL_history <- LL_mixt_normal(x = x, mu = mu, sigma = sigma, ratio = ratio)
  params_history <- tibble(iter = 0,
                           component = as.character(1:n_components),
                           mu = mu,
                           sigma = sigma,
                           ratio = ratio)
  # EM algorithm
  for (iter in 1:max_iter) {
    # E-step : gammma
    likelihood <- density_mixt_normal(x = x, mu = mu, sigma = sigma, ratio = ratio)
    gamma_each_component <- as.matrix(
      map2_df(.x = likelihood[ , 3:(2+n_components)], .y = ratio, .f = function(x, y){x * y}) /
        likelihood$prob_density
      )
    colnames(gamma_each_component) <- as.character(1:n_components) %>%
      map_chr(.f = ~paste0("gamma", .))
    sum_gamma <- colSums(gamma_each_component)
    # M-step
    ratio <- sum_gamma / sample_size    # MLE of ratio
    mu <- as.vector(x %*% gamma_each_component) / sum_gamma    # MLE of mu
    ncol <- length(x); nrow <- n_components    # MLE of sigma
    x_matrix <- matrix(x, byrow = TRUE, nrow = nrow, ncol = ncol)
    mu_matrix <- matrix(mu, nrow = nrow, ncol = ncol)
    sigma <- sqrt(
      diag((x_matrix - mu_matrix) %*% (gamma_each_component * t(x_matrix - mu_matrix))) / sum_gamma
      )
    LL_history <- append(LL_history,        # recoding history...
                         LL_mixt_normal(x = x, mu = mu, sigma = sigma, ratio = ratio))
    params_history <- bind_rows(
      params_history,
      tibble(iter = iter,
             component = as.character(1:n_components),
             mu = mu,
             sigma = sigma,
             ratio = ratio)
    )
    # coveragement
    if (abs(LL_history[iter+1]-LL_history[iter]) < tol){
      break    
    }
  }
  # 3. output
  n_iter <- iter
  LL_history_df <- tibble(iter = 0:n_iter, log_likelihood = LL_history)
  estimated_component <- str_c("component", max.col(gamma_each_component))
  data_estimated_component <- tibble(x = x,
                                     estimated_component = estimated_component)
  LL_last <- LL_history_df %>% filter(iter == n_iter) %>% .$log_likelihood
  AIC <- -2 * LL_last + 2 * (3 * n_components - 1)
  BIC <- -2 * LL_last + (3 * n_components - 1) * log(sample_size)
  params_last <- params_history %>% filter(iter == n_iter) %>% select(-iter)
  obj <- list(params = params_last,
              log_likelihood = LL_last,
              AIC = AIC,
              BIC = BIC,
              estimated_component = data_estimated_component,
              n_iter = n_iter,
              params_history = params_history,
              log_likelihood_history = LL_history_df)
  class(obj) <- "EM_MixtNormal"    # define class of the result object...
  return(obj)
}





#' print result of EM_Mixt_Normal
#' 
#' @param x <EM_MixtNormal> the result object of the function : em_mixt_normal
#' @param ... additional arguments
#' @export
#' 
print.EM_MixtNormal <- function(x, ...){
  # some calculations
  n_components <- length(x$params$component)
  component_names <- str_c("component_", 1:n_components, ":")
  # print some results...
  cat("* Parameters of Components:\n")
  print(as.data.frame(x$params %>% select(-component)), row.names = component_names)
  cat("attributes : $params, $log_likelihood, $AIC, $BIC, $estimated_component, $n_iter")
}





#' summary result of EM_Mixt_Normal
#' 
#' summary.EM_MixtNormal used to procedure result summaries of the result of the function : EM_mixt_normal.
#' @param object <EM_MixtNormal> the result object of the function : 
#' @param ... additional arguments affecting the summary produced.
#' 
#' @importFrom dplyr group_by
#' @importFrom dplyr summarize
#' @importFrom dplyr select
#' @importFrom dplyr n
#' @export
#' 
summary.EM_MixtNormal <- function(object, ...){
  # some calculations
  n_components <- length(object$params$component)
  component_names <- str_c("component_", 1:n_components, ":")
  num_components <- object$estimated_component %>%
    group_by(estimated_component) %>%
    summarize(numbers = n()) %>%
    .$numbers
  metrics <- c(object$log_likelihood, object$AIC, object$BIC, object$n_iter)
  names(metrics) <- c("log_likelihood", "AIC", "BIC", "iterations")
  
  # print some results...
  cat("* Numbers of Components:\n")
  print(data.frame(num_components = num_components, row.names = component_names))
  cat("\n")
  cat("* Parameters of Components:\n")
  print(as.data.frame(object$params %>% select(-component)), row.names = component_names)
  cat("\n")
  cat("")
  print(metrics)
}




#' Plot of history of loglikelihood
#' 
#' @param x <EM_MixtNormal> the result object of the function : 
#' 
#' @importFrom ggplot2 ggplot
#' @importFrom ggplot2 aes
#' @importFrom ggplot2 geom_line
#' @importFrom ggplot2 ggtitle
#' @export
#' 
plot_LL <- function(x){
  plt <- ggplot(data = x$log_likelihood_history,    # 更新結果の可視化
         mapping = aes(x = iter, y = log_likelihood)) +
    geom_line() +
    ggtitle("History of log likelihood")
  return(plt)
}





#' Plot of histogram of components
#' 
#' @param x <EM_MixtNormal> the result object of the function : EM_mixt_normal
#' @param binwidth <int_scalar> binwidth of histogram
#' 
#' @importFrom ggplot2 ggplot
#' @importFrom ggplot2 aes
#' @importFrom ggplot2 geom_histogram
#' @importFrom ggplot2 ggtitle
#' @export
#' 
plot_components <- function(x, binwidth){
  plt <- ggplot(data = x$estimated_component,
                mapping = aes(x = x, fill = estimated_component)) +
    geom_histogram(binwidth = binwidth, alpha = 0.3) +
    ggtitle("Result of component estimation : EM-algorithm")
  return(plt)
}





#' predict component that each datapoint belongs to
#' 
#' @param object <EM_MixtNormal> result of EM_mixt_normal
#' @param x <double_scalar> 1-dim. data points
#' @param ... additional arguments
#' 
#' @importFrom purrr pmap
#' @importFrom stats dnorm
#' @export
#' 
predict.EM_MixtNormal <- function(object, x, ...){
  n_components <- length(object$params$component)
  params_list <- list(mu = object$params$mu,
                      sigma = object$params$sigma,
                      ratio = object$params$ratio)
  gamma <- params_list %>% pmap(.f = function(mu, sigma, ratio){
    ratio * dnorm(x, mu, sigma)
  })
  obj <- max.col(matrix(unlist(gamma), ncol = n_components))
  return(obj)
}






#' plotting history of EM-algoritm with gif file
#' 
#' @param result <EM_MixtNormal>
#' @param width <double_scalar> image size
#' @param height <double_scalar> image size
#' @y_max <double_scalar> y_max
#' @param file_name <string> gif file name
#' 
#' @importFrom stringr str_c
#' @importFrom gifski gifski
#' @importFrom ggplot2 ggplot
#' @importFrom ggplot2 geom_histogram
#' @importFrom ggplot2 stat_function
#' @importFrom ggplot2 ggtitle
#' @importFrom ggplot2 ggsave
#' @importFrom ggplot2 ylim
#' @export
#' 
plot_history <- function(result, width = 5.00, height = 5.00, file_name = "history_of_EM"){
  n_iter <- result$n_iter
  n_components <- length(result$params$component)
  x_min <- min(result$estimated_component$x)
  x_max <- max(result$estimated_component$x)
  y_max <- 5 * 1 / (x_max - x_min)
  png_path <- str_c(tempdir(), "/plt", 0:n_iter, ".png")
  for(i in 1:(n_iter + 1)){
    params_each_iter <- result$params_history %>% filter(iter == (i - 1))
    mu <- params_each_iter$mu
    sigma <- params_each_iter$sigma
    ratio <- params_each_iter$ratio
    plt <- ggplot(data = result$estimated_component,
                  mapping = aes(x = x)) +
      geom_histogram(aes(y=..density..), binwidth = 2.0, alpha = 0.5) +
      stat_function(fun = function(x,mu,sigma,ratio){density_mixt_normal(x,mu,sigma,ratio)$prob_density},
                    args = list(mu = mu, sigma = sigma, ratio = ratio),
                    colour = "blue") +
      ggtitle(paste0("History of EM-algorithm, iteration : ", (i - 1), "/", n_iter, ".")) +
      ylim(c(0, y_max))
    for(j in 1:n_components){
      plt <- plt + stat_function(fun = function(x, mu, sigma, ratio){ratio*dnorm(x,mu,sigma)},
                                 args = list(mu = mu[j], sigma = sigma[j], ratio = ratio[j]),
                                 colour = "blue",
                                 linetype = "dashed")
    }
    ggsave(png_path[i], width = width, height = height)
  }
  gif_path <- file.path(getwd(), str_c(file_name, ".gif"))
  gifski(png_path, gif_path, width = width * 100, height = height * 100)
  unlink(png_path)
}

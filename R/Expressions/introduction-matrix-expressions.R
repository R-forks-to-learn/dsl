## Parsing #######################################################
m <- function(data) {
  structure(data, 
            nrow = nrow(data),
            ncol = ncol(data),
            def_expr = deparse(substitute(data)),
            class = c("matrix_data", "matrix_expr", class(data)))
}
matrix_mult <- function(A, B) {
  structure(list(left = A, right = B),
            nrow = nrow(A),
            ncol = ncol(B),
            class = c("matrix_mult", "matrix_expr"))
}


`*.matrix_expr` <- function(A, B) {
  matrix_mult(A, B)
}



## Helper functions ##############################################
dim.matrix_expr <- function(x) {
  c(attr(x, "nrow"), attr(x, "ncol"))
}

toString.matrix_expr <- function(x, ...) {
  paste0("[", attr(x, "def_expr"), "]")
}
toString.matrix_mult <- function(x, ...) {
  paste0("(", toString(x$left), " * ", toString(x$right), ")")
}
print.matrix_expr <- function(x, ...) {
  print(toString(x))
}




## Evaluating ####################################################
backtrack_matrix_mult <- function(i, j, dims, tbl, matrices) {
  if (i == j) {
    matrices[[i]]
  } else {
    k <- i:(j - 1)
    candidates <- dims[i,1]*dims[k,2]*dims[j,2] + tbl[i,k] + tbl[k + 1,j]
    split <- k[which(tbl[i,j] == candidates)][1]
    left <- backtrack_matrix_mult(i, split, dims, tbl, matrices)
    right <- backtrack_matrix_mult(split + 1, j, dims, tbl, matrices)
    matrix_mult(left, right)
  }
}

arrange_optimal_matrix_mult <- function(matrices) {
  n <- length(matrices)
  dims <- matrix(0, nrow = n, ncol = 2)
  for (i in seq_along(matrices)) {
    dims[i,] <- dim(matrices[[i]])
  }
  
  tbl <- matrix(0, nrow = n, ncol = 4)
  for (len in 2:n) {
    for (i in 1:(n - len + 1)) {
      j <- i + len - 1
      k <- i:(j - 1)
      tbl[i,j] <- min(dims[i,1]*dims[k,2]*dims[j,2] + tbl[i,k] + tbl[k + 1,j])
    }
  }
  
  backtrack_matrix_mult(1, n, dims, tbl, matrices)  
}

count_mult_components <- function(expr) UseMethod("count_mult_components")
count_mult_components.default <- function(expr) 1
count_mult_components.matrix_mult <- function(expr)
  count_mult_components(expr$left) + count_mult_components(expr$right)

collect_basic_matrices <- function(matrix_expr) {
  n <- count_mult_components(matrix_expr)
  matrices <- vector("list", length = n)
  i <- 1
  collect <- function(matrix_expr) {
    if (inherits(matrix_expr, "matrix_mult")) {
      collect(matrix_expr$left)
      collect(matrix_expr$right)
    } else {
      matrices[[i]] <<- matrix_expr
      i <<- i + 1
    }  
  }
  collect(matrix_expr)
  matrices
}

rearrange_matrix_expr <- function(expr) UseMethod("rearrange_matrix_expr")
rearrange_matrix_expr.default <- function(expr) expr
rearrange_matrix_expr.matrix_mult <- function(expr) {
  matrices <- collect_basic_matrices(expr)
  arrange_optimal_matrix_mult(matrices)
}

eval_matrix_expr <- function(expr) UseMethod("eval_matrix_expr")
eval_matrix_expr.matrix_data <- function(expr) expr
eval_matrix_expr.matrix_mult <- function(expr) {
  eval_matrix_expr(expr$left) %*% eval_matrix_expr(expr$right)
}

## Forcing evaluation... #######################################
v <- function(expr) eval_matrix_expr(rearrange_matrix_expr(expr))

library(magrittr)
v2 <- . %>% rearrange_matrix_expr %>% eval_matrix_expr

`%.%` <- function(g, f) function(...) g(f(...))
v3 <- eval_matrix_expr %.% rearrange_matrix_expr


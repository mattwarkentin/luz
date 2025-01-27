#' Pipe operator
#'
#' See \code{magrittr::\link[magrittr:pipe]{\%>\%}} for details.
#'
#' @name %>%
#' @rdname pipe
#' @keywords internal
#' @export
#' @importFrom magrittr %>%
#' @importFrom zeallot %<-%
#'
#' @usage lhs \%>\% rhs
NULL

`%||%` <- function(x, y) {
  if (is.null(x))
    y
  else
    x
}

utils::globalVariables(c("self"))

has_method <- function(x, name) {
  if (!is.null(x$public_methods[[name]]))
    TRUE
  else if (!is.null(x$get_inherit()))
    has_method(x$get_inherit(), name)
  else
    FALSE
}


get_forward <- function(x) {
  if (!is.null(x$public_methods[["forward"]]))
    x$public_methods[["forward"]]
  else if (!is.null(x$get_inherit()))
    get_forward(x$get_inherit())
  else
    rlang::abort("No `forward` method found.")
}

has_forward_method <- function(x) {
  test_module <- torch::nn_module(initialize = function() {})
  nn_forward <- test_module$get_inherit()$public_methods$forward
  forward <- get_forward(x)
  !isTRUE(identical(nn_forward, forward))
}

bind_context <- function(x, ctx) {
  e <- rlang::fn_env(x$clone) # the `clone` method must always exist in R6 classes
  rlang::env_bind(e, ctx = ctx)

  if (!is.null(x <- x$.__enclos_env__$super))
    bind_context(x, ctx)

  invisible(NULL)
}

get_init <- function(x) {

  if (!is.null(x$public_methods[["initialize"]]))
    return(x$public_methods[["initialize"]])
  else
    return(get_init(x$get_inherit()))

}

inform <- function(message) {
  e <- rlang::caller_env()
  ctx <- rlang::env_get(e, "ctx", inherit = TRUE)

  verbose <- ctx$verbose

  if (verbose)
    rlang::inform(message)

  invisible(NULL)
}

utils::globalVariables(c("super"))

make_class <- function(name, ..., private, active, inherit, parent_env, .init_fun) {
  public <- rlang::list2(...)

  e <- new.env(parent = parent_env)

  e$inherit <- inherit

  r6_class <- R6::R6Class(
    classname = name,
    inherit = inherit,
    public = public,
    private = private,
    active = active,
    parent_env = e,
    lock_objects = FALSE
  )

  e$r6_class <- r6_class
  init <- get_init(r6_class)


  f <- rlang::new_function(
    args = rlang::fn_fmls(init),
    body = rlang::expr({
      obj <- R6::R6Class(
        inherit = r6_class,
        public = list(
          initialize = function() {
            super$initialize(!!!rlang::fn_fmls_syms(init))
          }
        ),
        private = private,
        active = active,
        lock_objects = FALSE,
        parent_env = rlang::current_env()
      )
      if (.init_fun)
        obj$new()
      else
        obj
    })
  )
  attr(f, "r6_class") <- r6_class
  f
}

# from https://glue.tidyverse.org/articles/transformers.html
sprintf_transformer <- function(text, envir) {
  m <- regexpr(":.+$", text)
  if (m != -1) {
    format <- substring(regmatches(text, m), 2)
    regmatches(text, m) <- ""
    res <- eval(parse(text = text, keep.source = FALSE), envir)
    do.call(sprintf, list(glue::glue("%{format}"), res))
  } else {
    eval(parse(text = text, keep.source = FALSE), envir)
  }
}

check_installed <- function (pkg, fun) {
  if (rlang::is_installed(pkg)) {
    return()
  }
  rlang::abort(c(paste0("The ", pkg, " package must be installed in order to use `",
                 fun, "`"), i = paste0("Do you need to run `install.packages('",
                                       pkg, "')`?")))
}



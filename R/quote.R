#' @include DBConnection.R
NULL

#' SQL quoting
#'
#' This set of classes and generics make it possible to flexibly deal with SQL
#' escaping needs. By default, any user supplied input to a query should be
#' escaped using either [dbQuoteIdentifier()] or [dbQuoteString()]
#' depending on whether it refers to a table or variable name, or is a literal
#' string.
#' These functions may return an object of the `SQL` class,
#' which tells DBI functions that a character string does not need to be escaped
#' anymore, to prevent double escaping.
#' The `SQL` class has associated the `SQL()` constructor function.
#'
#' @section Implementation notes:
#'
#' DBI provides default generics for SQL-92 compatible quoting. If the database
#' uses a different convention, you will need to provide your own methods.
#' Note that because of the way that S4 dispatch finds methods and because
#' SQL inherits from character, if you implement (e.g.) a method for
#' `dbQuoteString(MyConnection, character)`, you will also need to
#' implement `dbQuoteString(MyConnection, SQL)` - this should simply
#' return `x` unchanged.
#'
#' @param x A character vector to label as being escaped SQL.
#' @param ... Other arguments passed on to methods. Not otherwise used.
#' @return An object of class `SQL`.
#' @export
#' @examples
#' dbQuoteIdentifier(ANSI(), "SELECT")
#' dbQuoteString(ANSI(), "SELECT")
#'
#' # SQL vectors are always passed through as is
#' var_name <- SQL("SELECT")
#' var_name
#'
#' dbQuoteIdentifier(ANSI(), var_name)
#' dbQuoteString(ANSI(), var_name)
#'
#' # This mechanism is used to prevent double escaping
#' dbQuoteString(ANSI(), dbQuoteString(ANSI(), "SELECT"))
SQL <- function(x) new("SQL", x)

#' @rdname SQL
#' @export
#' @aliases
#'   SQL-class
setClass("SQL", contains = "character")

#' @rdname hidden_aliases
#' @export
setMethod("show", "SQL", function(object) {
  cat(paste0("<SQL> ", object@.Data, collapse = "\n"), "\n", sep = "")
})


#' Quote identifiers
#'
#' Call this method to generate a string that is suitable for
#' use in a query as a column name, to make sure that you
#' generate valid SQL and avoid SQL injection.
#'
#' @param conn A subclass of [DBIConnection-class], representing
#'   an active connection to an DBMS.
#' @param x A character vector to quote as identifier.
#' @param ... Other arguments passed on to methods.
#'
#' @inherit DBItest::spec_sql_quote_identifier return
#' @inheritSection DBItest::spec_sql_quote_identifier Specification
#'
#' @family DBIResult generics
#' @export
#' @examples
#' # Quoting ensures that arbitrary input is safe for use in a query
#' name <- "Robert'); DROP TABLE Students;--"
#' dbQuoteIdentifier(ANSI(), name)
#'
#' # SQL vectors are always passed through as is
#' var_name <- SQL("select")
#' var_name
#'
#' dbQuoteIdentifier(ANSI(), var_name)
#'
#' # This mechanism is used to prevent double escaping
#' dbQuoteIdentifier(ANSI(), dbQuoteIdentifier(ANSI(), name))
setGeneric("dbQuoteIdentifier",
  def = function(conn, x, ...) standardGeneric("dbQuoteIdentifier")
)

#' @rdname hidden_aliases
#' @export
setMethod("dbQuoteIdentifier", "DBIConnection",
  function(conn, x, ...) {
    if (is(x, "SQL")) return(x)
    if (is(x, "Table")) {
      return(SQL(paste0(dbQuoteIdentifier(conn, x@name), collapse = ".")))
    }
    if (!is.character(x)) stop("x must be character or SQL", call. = FALSE)

    if (any(is.na(x))) {
      stop("Cannot pass NA to dbQuoteIdentifier()", call. = FALSE)
    }
    # Avoid fixed = TRUE due to https://github.com/r-dbi/DBItest/issues/156
    x <- gsub('"', '""', enc2utf8(x))
    if (length(x) == 0L) {
      SQL(character())
    } else {
      # Not calling encodeString() here to keep things simple
      SQL(paste('"', x, '"', sep = ""))
    }
  }
)

#' Quote literal strings
#'
#' Call this method to generate a string that is suitable for
#' use in a query as a string literal, to make sure that you
#' generate valid SQL and avoid SQL injection.
#'
#' @param conn A subclass of [DBIConnection-class], representing
#'   an active connection to an DBMS.
#' @param x A character vector to quote as string.
#' @param ... Other arguments passed on to methods.
#'
#' @inherit DBItest::spec_sql_quote_string return
#' @inheritSection DBItest::spec_sql_quote_string Specification
#'
#' @family DBIResult generics
#' @export
#' @examples
#' # Quoting ensures that arbitrary input is safe for use in a query
#' name <- "Robert'); DROP TABLE Students;--"
#' dbQuoteString(ANSI(), name)
#'
#' # NAs become NULL
#' dbQuoteString(ANSI(), c("x", NA))
#'
#' # SQL vectors are always passed through as is
#' var_name <- SQL("select")
#' var_name
#' dbQuoteString(ANSI(), var_name)
#'
#' # This mechanism is used to prevent double escaping
#' dbQuoteString(ANSI(), dbQuoteString(ANSI(), name))
setGeneric("dbQuoteString",
  def = function(conn, x, ...) standardGeneric("dbQuoteString")
)

#' @rdname hidden_aliases
#' @export
setMethod("dbQuoteString", "DBIConnection",
  function(conn, x, ...) {
    if (is(x, "SQL")) return(x)
    if (!is.character(x)) stop("x must be character or SQL", call. = FALSE)

    # Avoid fixed = TRUE due to https://github.com/r-dbi/DBItest/issues/156
    x <- gsub("'", "''", enc2utf8(x))

    if (length(x) == 0L) {
      SQL(character())
    } else {
      # Not calling encodeString() here, see also http://stackoverflow.com/a/549244/946850
      # and especially the comment by Álvaro González
      str <- paste("'", x, "'", sep = "")
      str[is.na(x)] <- "NULL"
      SQL(str)
    }
  }
)

#' Quote literal values
#'
#' @description
#' Call these methods to generate a string that is suitable for
#' use in a query as a literal value of the correct type, to make sure that you
#' generate valid SQL and avoid SQL injection.
#'
#' @inheritParams dbQuoteString
#' @param x A vector to quote as string.
#'
#' @inherit DBItest::spec_sql_quote_literal return
#' @inheritSection DBItest::spec_sql_quote_literal Specification
#'
#' @family DBIResult generics
#' @export
#' @examples
#' # Quoting ensures that arbitrary input is safe for use in a query
#' name <- "Robert'); DROP TABLE Students;--"
#' dbQuoteLiteral(ANSI(), name)
#'
#' # NAs become NULL
#' dbQuoteLiteral(ANSI(), c(1:3, NA))
#'
#' # Logicals become integers by default
#' dbQuoteLiteral(ANSI(), c(TRUE, FALSE, NA))
#'
#' # Raw vectors become hex strings by default
#' dbQuoteLiteral(ANSI(), list(as.raw(1:3), NULL))
#'
#' # SQL vectors are always passed through as is
#' var_name <- SQL("select")
#' var_name
#' dbQuoteLiteral(ANSI(), var_name)
#'
#' # This mechanism is used to prevent double escaping
#' dbQuoteLiteral(ANSI(), dbQuoteLiteral(ANSI(), name))
setGeneric("dbQuoteLiteral",
  def = function(conn, x, ...) standardGeneric("dbQuoteLiteral")
)



#' @rdname hidden_aliases
#' @export
setMethod("dbQuoteLiteral", "DBIConnection",
  function(conn, x, ...) {
    # Switchpatching to avoid ambiguous S4 dispatch, so that our method
    # is used only if no alternatives are available.

    if (is(x, "SQL")) return(x)

    if (is.character(x)) return(dbQuoteString(conn, x))

    if (is.list(x)) {
      blob_data <- vapply(
        x,
        function(x) {
          if (is.null(x)) "NULL"
          else if (is.raw(x)) paste0("X'", paste(format(x), collapse = ""), "'")
          else {
            stop("Lists must contain raw vectors or NULL", call. = FALSE)
          }
        },
        character(1)
      )
      return(SQL(blob_data))
    }

    if (is.logical(x)) x <- as.numeric(x)
    x <- as.character(x)
    x[is.na(x)] <- "NULL"
    SQL(x)
  }
)

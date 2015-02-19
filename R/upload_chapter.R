#' Create or update a chapter
#' 
#' @usage upload_chapter(input_file, force = FALSE, open = TRUE, ...)
#' @param input_file Path to the ".Rmd" file to be uploaded
#' @param force boolean, FALSE by default, specifies whether exercises should be removed. If set, will prompt for confirmation.
#' @param open boolean, TRUE by default, determines whether a browser window should open, showing the course creation web interface
#' @param ... Extra arguments to be passed to the \code{slidify} function under the hood
#' @return No return values.
#' @examples
#' \dontrun{
#' # Upload without possibly deleting existing exercises
#' upload_chapter("chapter1.Rmd")
#' 
#' # Completely sync online chapter with your local markdown file
#' upload_chapter("chapter1.Rmd", force = TRUE)
#' }
#' 
#' @importFrom slidify slidify
#' @export
upload_chapter = function(input_file, force = FALSE, open = TRUE, ...) {
  if (!hasArg(input_file)) { return(message("Error: You need to specify a chapter Rmd file.")) }
  if (!datacamp_logged_in()) { datacamp_login() }
  if (!file.exists("course.yml")) { return(message("Error: Seems like there is no course.yml file in the current directory.")) }
  if (force == TRUE) {
    sure = readline("Using 'force' deletes exercises. Are you sure you want to continue? (Y/N) ")
    if (!(sure == "y" || sure == "Y" || sure == "yes" || sure == "Yes")) { return(message("Aborted.")) }
  }
  #   if (skip_validation == TRUE) {
  #     sure = readline("Using 'skip_validation' implies that the exercises will not be checked for correctness. Are you sure you want to continue? (Y/N) ")
  #     if (!(sure == "y" || sure == "Y" || sure == "yes" || sure == "Yes")) { return(message("Aborted.")) }
  #   }
  if (length(get_chapter_id(input_file)) == 0) {
    sure = readline("Chapter not found in course.yml. This will create a new chapter, are you sure you want to continue? (Y/N) ")
    if (!(sure == "y" || sure == "Y" || sure == "yes" || sure == "Yes")) { return(message("Aborted.")) }
  }
  payload = suppressWarnings(slidify(input_file, return_page = TRUE,...)) # Get the payload  
  theJSON = render_chapter_json_for_datacamp(input_file, payload, force, skip_validation = TRUE) # Get the JSON
  upload_chapter_json(theJSON, input_file, open = open) # Upload everything
  clean_leftovers(input_file)
}


#' Upload the chapter json
#' @param theJSON the JSON string to be posted
#' @param file_name chapter file name that is being uploaded
#' @param open whether or not to open the teach website after upload.
#' 
#' @importFrom httr POST content add_headers
upload_chapter_json = function(theJSON, file_name, open = TRUE) {
  base_url = paste0(.DATACAMP_ENV$base_url, "/chapters/create_from_r.json")
  auth_token = .DATACAMP_ENV$auth_token
  url = paste0(base_url,"?auth_token=", auth_token)
  x = try(POST(url = url, body = theJSON, add_headers(c(`Content-Type` = "application/json", `Expect` = ""))))
  
  if ( class(x) != "response" ) {
    stop("Something went wrong. We didn't get a valid response from the datacamp server. Try again or contact info@datacamp.com in case you keep experiencing this problem.")
  } else { 
    if (is.list(content(x)) ) { 
      if ("course" %in% names(content(x)) ) {  
        course = content(x)$course
        chapter = content(x)$chapter
        new = content(x)$created
        message(paste0("Changes made to course (id:",course$id,"): \"", course$title,"\":"))
        if (new == TRUE) {
          message(paste0("\tCreated new chapter (id:", chapter$id,"): \"", chapter$title,"\".")) 
        } else {
          message(paste0("\tExisting chapter (id:",chapter$id,"): \"", chapter$title,"\" was updated."))
        }
        add_chapter_to_course_yml(file_name, as.integer(chapter$id))
        if (open) {
          browseURL(paste0(.DATACAMP_ENV$redirect_base_url, "/", course$id))
        } 
      } 
      if ("message" %in% names(content(x))) {
        message(content(x)$message)
      }
      if ("result" %in% names(content(x))) {
        if ("testresults" %in% names(content(x)$result)) {
          invisible(lapply(content(x)$result$testresults, function(x) message(x[[2]])))
        }
      }
      if ( "error" %in% names(content(x)) ) {
        message(paste0("Something went wrong:\n", content(x)$error ))
      } 
    } else {
      message(paste0("Something went wrong. Please check whether your course was correctly uploaded to datacamp.com."))
    } 
  } 
}
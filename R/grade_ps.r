#' Grade your problem set
#' 
#' The command will rerun and check all chunks of your problem set and grade it, i.e. it determines which tests are passed or not. The results are stored in a grading file: psname___username.grd, which will be part of the submitted solution. The function works similarly than check.problem.set, but makes sure that all exercies are checked.
#'@export
grade.ps = function(ps=get.ps(), user.name=get.user()$name,  ps.name=ps$name,stud.path=ps$stud.path, stud.short.file=ps$stud.short.file, reset=TRUE, set.warning.1=TRUE, verbose=FALSE, catch.errors=TRUE, from.knitr=!interactive(), use.null.device=TRUE) {

  restore.point("grade.ps")

  
  if (from.knitr) {
    cat("Cannot grade when called from knitr")
    return()
  }

  if (set.warning.1) {
    if (options()$warn<1)
      options(warn=1)
  }
  if (!isTRUE(try(file.exists(stud.path),silent = TRUE))) {
    str= paste0("I could not find your problem set directory '", stud.path,"'.")
    stop(str,call. = FALSE)
  }
  if (!file.exists(paste0(stud.path,"/", stud.short.file))) {
    str= paste0("I could not find your file '", stud.short.file,"' in your problem set folder '",stud.path,"'.")
    stop(str,call. = FALSE)    
  }
  
  setwd(stud.path)
  log.event(type="grade_ps")
  
  ps = get.or.init.ps(ps.name,stud.path, stud.short.file, reset)
  ps$catch.errors = catch.errors
  ps$use.null.device = use.null.device
  
  set.ps(ps)
  ps$warning.messages = list()
  
  user = get.user(user.name)  
  cdt = ps$cdt
  edt = ps$edt
  
  rmd.code = readLines(ps$stud.file)
  ps$stud.code = rmd.code
  cdt$stud.code = get.stud.chunk.code(ps=ps)
  cdt$code.is.task = cdt$stud.code == cdt$task.txt
  cdt$chunk.changed = cdt$stud.code != cdt$old.stud.code
  cdt$old.stud.code = cdt$stud.code
  
  ps$cdt = cdt
  # Check all exercises
  i = 1
  for (i in edt$ex.ind) {
    ex.name = edt$ex.name[i]
    ret <- FALSE
    display("Grade exercise ", ex.name)
    
    
    if (!is.false(ps$catch.errors)) {
      ret = tryCatch(check.exercise(ex.ind=i, verbose=verbose, check.all=TRUE),
                   error = function(e) {ps$failure.message <- as.character(e)
                                        return(FALSE)})
    } else {
      ret = check.exercise(ex.ind=i, verbose=verbose, check.all=TRUE)
    }
    # Copy variables into global env
    copy.into.envir(source=ps$stud.env,dest=.GlobalEnv, set.fun.env.to.dest=TRUE)
    save.ups()
    if (ret==FALSE) {
      edt$ex.solved[i] = FALSE
      if (cdt$code.is.task[ps$chunk.ind]) {
        ps$failure.message = paste0("You have not yet started with chunk ", cdt$chunk.name[ps$chunk.ind])
      }
      message = ps$failure.message
      display(message)
    } else if (ret=="warning") {
      message = paste0(ps$warning.messages,collapse="\n\n")
      message(paste0("Warning: ", message))
    } else {
      edt$ex.solved[i] = TRUE
    }
  }

  ups = get.ups()
  
  grd = as.list(ups)
  grd$tdt = as.data.frame(grd$tdt)
  grd$rmd.code = rmd.code  
  grd$grade.time = Sys.time()
  grd$rtutor.version = packageVersion("RTutor")
  
  sum.fun = function(df) {
    summarise(df,
      ps.name = ps.name,
      user.name = user.name,
      num.test = length(test.e.ind),
      num.success = sum(success),
      share.solved=round(sum(success)/num.test*100),
      num.hints = sum(num.hint),
      finished.time = max(success.date, na.rm=TRUE),
      grade.time = grd$grade.time
    )
  }
  grd$total = sum.fun(grd$tdt)
  grd$by.chunk = sum.fun(group_by(grd$tdt,chunk.ps.ind))
  grd$by.ex = sum.fun(group_by(grd$tdt,ex.ind))
  
  
  grd$hash = digest::digest(list(grd$user.name,grd$ps.name,grd$grade.time,grd$total))
  
  try(grd$log.txt <- readLines(ps$log.file))
  try(grd$log.df <- import.log(txt=grd$log.txt))
  #object.size(grd)
  
  grd.file = paste0(grd$ps.name,"_",grd$user.name,".sub")
  grd = as.environment(grd)
  save(grd,file=grd.file)
  
}
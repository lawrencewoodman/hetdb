# A Human Editable Text Database module
#
# Copyright (C) 2024 Lawrence Woodman <https://lawrencewoodman.github.io/>
#
# Licensed under an MIT licence.  Please see LICENCE.md for details.
#

# TODO: Test on 8.5 to check
package require Tcl 8.5

namespace eval hetdb {
  namespace export {[a-z]*}
  namespace ensemble create
}


# TODO: rename?
proc hetdb::read {filename} {
  set isErr [catch {
    set fd [open $filename r]
    set db [::read $fd]
    close $fd
  } err]
  if {$isErr} {
    return -code error $err
  }

  if {![IsDict $db]} {
    return -code error "outer structure of database not valid"
  }
  dict for {tablename rows} $db {
    if {![string is list $rows]} {
      return -code error "structure of table not valid, table: $tablename"
    }
    set rowNum 0
    foreach row $rows {
      if {![IsDict $row]} {
        return -code error "structure of row not valid, table: $tablename, row: $rowNum"
      }
      incr rowNum
    }
  }

  return $db
}


# hetdb::for --
#
# Iterate over each row of a table.
#
# The break and continue statements may be invoked inside body, with the same
# effect as in the ::for command.
#
# Arguments:
#   db        The database that contains the table.
#   tablename The name of the table.
#   varname   The name of the variable that will be set to the contents of
#             the row.  The contents of each row is a dictionary of fields
#             and their values.
#   body      The script which will be evaluated for each row of the table
#             and will have varname set with the contents of each row.
#
# Results:
#   None.
#
proc hetdb::for {db tablename varname body} {
  foreach e [dict get $db $tablename] {
    uplevel 1 [list set $varname $e]
    # Exception handling within body from Tcl and the Tk Toolkit, 2nd Edition
    # Chapter 13 - Errors and Exceptions
    # Codes: 0 Normal return, 1 Error, 2 return command invoked
    #        3 break command invoked, 4 continue command invoked
    set retcode [catch {uplevel 1 $body} res options]
    switch -- $retcode {
      0 -
      4       {}
      3       {return}
      default {dict incr options -level
               return -options $options $res
              }
    }
  }
}


# TODO: specify a prefix for fields rather than fieldname varname?
# TODO: Rename? or add as a switch to ::for command
proc hetdb::forfields {db tablename fieldlist body} {
  foreach row [dict get $db $tablename] {
    foreach fieldspec $fieldlist {
      lassign $fieldspec fieldname varname
      if {$varname ne ""} {
        uplevel 1 [list set $varname [dict get $row $fieldname]]
      } else {
        uplevel 1 [list set $fieldname [dict get $row $fieldname]]
      }
    }
    # Exception handling within body from Tcl and the Tk Toolkit, 2nd Edition
    # Chapter 13 - Errors and Exceptions
    # Codes: 0 Normal return, 1 Error, 2 return command invoked
    #        3 break command invoked, 4 continue command invoked
    set retcode [catch {uplevel 1 $body} res options]
    switch -- $retcode {
      0 -
      4       {}
      3       {return}
      default {dict incr options -level
               return -options $options $res
              }
    }
  }
}


proc hetdb::sort {db tablename command} {
  set tb [dict get $db $tablename]
  dict set db $tablename [lsort -command $command $tb]
}


# TODO: Rename?
# TODO: Improve error message format
# DOCUMENT: Unique fields are trimmed before comparing
proc hetdb::verify {db tabledefname} {
  hetdb::for $db $tabledefname tabledef {
    set tablename [dict get $tabledef name]
    set mandatory [list]
    set unique [list]
    if {[dict exists $tabledef mandatory]} {
      set mandatory [dict get $tabledef mandatory]
    }
    if {[dict exists $tabledef unique]} {
      set unique [dict get $tabledef unique]
      set uniques [dict create]
      foreach ufield $unique {
        dict set uniques $ufield [dict create]
      }
    }
    hetdb::for $db $tablename row {
      set keys [dict keys $row]
      foreach mankey $mandatory {
        if {$mankey ni $keys} {
          return [list false "table: $tablename, missing key: $mankey"]
        }
      }
      foreach key $keys {
        if {$key in $unique} {
          set val [string trim [dict get $row $key]]
          if {[dict exists $uniques $key $val]} {
            return [list false "table: $tablename, key isn't unique: $key"]
          } else {
            dict set uniques $key $val 1
          }
        }
      }
    }
  }
  return {true {}}
}


proc hetdb::IsDict value {
  expr {![catch {dict size $value}]}
}


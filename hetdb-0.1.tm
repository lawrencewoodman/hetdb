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


# ---------------------------------------------------------------------------
# A valid database
# TODO: Uses table '_tabledef' to validate database
# TODO: Unique fields are trimmed while comparing
# TODO: Document database format, tables, _tabledef and table names
# ---------------------------------------------------------------------------


# hetdb::read
#
# Read an entire database from a text file.
#
# Arguments:
#   filename  The name of a text file containing a database. It is an
#             error to read a file which isn't a valid database and whose
#             tables don't conform to any entries in _tabledef.
#
# Results:
#   A database.
#
proc hetdb::read {filename} {
  set isErr [catch {
    set fd [open $filename r]
    set db [::read $fd]
    close $fd
  } err]
  if {$isErr} {
    return -code error $err
  }

  set err [validate $db]
  if {$err ne {}} {
    return -code error $err
  }

  return $db
}


# hetdb::for
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
  # TODO: handle tablename not exisiting
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


# hetdb::forfields
#
# Iterate over each row of a table.
#
# The break and continue statements may be invoked inside body, with the same
# effect as in the ::for command.
#
# Arguments:
#   db          The database that contains the table.
#   tablename   The name of the table.
#   fieldPrefix This is prefixed to each field to create the variables
#               for each field specified in fields.
#   fields      A list of fields whose values will retrieved for each row and
#               variables will be set with their value.  The field variable
#               names will consist of the field name prefixed with
#               fieldPrefix.  It is an error to attempt to access a field
#               which doesn't exist in a row.  Therefore, it is worth
#               specifying any fields used by this procedure as mandatory
#               and use the validate command to ensure they are present for
#               all rows of a table.
#   body        The script which will be evaluated for each row of the table
#               and will have the fields requested set for each row.
#
# Results:
#   None.
#
proc hetdb::forfields {db tablename fieldPrefix fields body} {
  # TODO: handle tablename not exisiting
  foreach row [dict get $db $tablename] {
    foreach fieldname $fields {
      if {![dict exists $row $fieldname]} {
        return -code error "field \"$fieldname\" missing from row"
      }
      uplevel 1 [list set $fieldPrefix$fieldname [dict get $row $fieldname]]
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


# hetdb::sort
#
# Sort a table.
#
# Arguments:
#   db        The database that contains the table.
#   tablename The name of the table.
#   command   A command to compare two rows of a table.  The command will
#             be called repeatedly with two arguments containing a row in
#             each.  This follows the same use as lsort -command.
#
# Results:
#   A database with the table sorted using command.
#
proc hetdb::sort {db tablename command} {
  # TODO: handle tablename not exisiting
  set tb [dict get $db $tablename]
  dict set db $tablename [lsort -command $command $tb]
}


# hetdb::validate
#
# Validate that a database is properly formed as are each of its tables.
# Each table must conform to any entries in the table _tabledef.
#
# Arguments:
#   db  The database to validate.
#
# Results:
#   An error string or {} if everything is correct.
#
proc hetdb::validate {db} {
  if {![IsDict $db]} {
    return "outer structure of database not valid"
  }

  lassign [GetTabledef $db] tabledef err
  if {$err ne {}} {
    return $err
  }

  dict for {tablename rows} $db {
    set err [ValidateTable $tabledef $tablename $rows]
    if {$err ne ""} {
      return $err
    }
  }

  return {}
}


# Verifies that table name contains only alpha-numeric characters and
# underscore.  If it begins with underscore then it can only be _tabledef
proc hetdb::ValidateTablename {tablename} {
  set validSpecialNames {_tabledef}
  if {[string match {_*} $tablename] && $tablename ni $validSpecialNames} {
    return "invalid table name \"$tablename\""
  }
  if {![regexp -nocase {^[[:alnum:]_]*$} $tablename]} {
    return "invalid table name \"$tablename\""
  }
  return {}
}


# Verifies that a table is properly formed and conforms to any definition
# in _tabledef
proc hetdb::ValidateTable {tabledef tablename rows} {
  set err [ValidateTablename $tablename]
  if {$err ne ""} {
    return $err
  }
  if {![string is list $rows]} {
    return "structure of table \"$tablename\" not valid"
  }
  set mandatory [MustDictGet $tabledef $tablename mandatory]
  set unique [MustDictGet $tabledef $tablename unique]
  set uniques [dict create]
  foreach ufield $unique {
    dict set uniques $ufield [dict create]
  }

  set rowNum 0
  foreach row $rows {
    if {![IsDict $row]} {
      return "structure of row $rowNum in table \"$tablename\" not valid"
    }
    set keys [dict keys $row]
    foreach mankey $mandatory {
      if {$mankey ni $keys} {
        return "mandatory field \"$mankey\" in table \"$tablename\" is missing"
      }
    }
    foreach key $keys {
      if {$key in $unique} {
        set val [string trim [dict get $row $key]]
        if {[dict exists $uniques $key $val]} {
          return "field \"$key\" in table \"$tablename\" isn't unique"
        } else {
          dict set uniques $key $val 1
        }
      }
    }
    incr rowNum
  }

  return {}
}


# Return the _tabledef table as a dictionary using each name as a key
# The table is return as the first element of a list, the second entry
# is an error if present
proc hetdb::GetTabledef {db} {
  set ret [dict create]
  set tabledefs [MustDictGet $db _tabledef]
  set tabledefTabledef {_tabledef {mandatory name unique name}}
  set err [ValidateTable $tabledefTabledef _tabledef $tabledefs]
  if {$err ne ""} {
    return [list {} $err]
  }
  foreach tabledef $tabledefs {
    set tablename [dict get $tabledef name]
    if {$tablename eq "_tabledef"} {
      return [list {} "can't define \"_tabledef\" in table \"_tabledef\""]
    }
    dict set ret $tablename mandatory [MustDictGet $tabledef mandatory]
    dict set ret $tablename unique [MustDictGet $tabledef unique]
  }

  return [list $ret {}]
}


# Returns whether value is a valid dictionary
proc hetdb::IsDict value {
  expr {![catch {dict size $value}]}
}


# Return the value for the key/key chain in dictionary or {}
proc hetdb::MustDictGet {dict args} {
  if {[llength $args] < 1} {
    return -code "invalid number of arguments"
  }
  set keys $args
  if {[dict exists $dict {*}$keys]} {
    return [dict get $dict {*}$keys]
  }
  return {}
}


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


# ============================================================================
#
# Database Format
# ===============
#
# A valid database is a Tcl dictionary where each key is a table name and the
# value is the contents of the table.
#
# Each table is a Tcl list where each element of the list is a row of the
# table.  Each row of the table is a Tcl dictionary where each key is a field
# and each value is the value of that field.
#
# Table names must only consist of alphanumeric or '_' characters.  A table
# name must not start with a '_' unless it is the '_tabledef' table described
# below.  A table name must not end with a '_'.
#
# Field names must only consist of alphanumeric or '_' characters.  A field
# name must not start with a '_' or end with a '_'.
#
#
# The '_tabledef' Table
# ---------------------
#
# The '_tabledef' table is an optional table used to describe tables.  If
# present, the database is checked against this to ensure that it is valid.
# Each row describes one table using the following fields:
#   name       The name of the table being described.
#   unique     A list of fields to check for all the rows to ensure that no
#              two rows have the same value for a field.  When comparing
#              values the strings are trimmed.
#   optional   A list of fields whose presence is optional in each row of a
#              table.
#   mandatory  A list of fields that must be present in each row of a table.
#
# ============================================================================



# hetdb::read
#
# Read an entire database from a text file.
#
# Arguments:
#   filename  The name of a text file containing a database. It is an
#             error to read a file which isn't a valid database and whose
#             tables don't conform to any entries in '_tabledef'.
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
#   ?switches?  See below.
#   db          The database that contains the table.
#   tablename   The name of the table. It is an error to attempt to access a
#               table that doesn't exist within the database.
#   fields      A list of field names whose values will retrieved for each
#               row.  If the field name doesn't exist in a row then {} will
#               be used as its value.
#   body        The script which will be evaluated for each row of the tablea.
#               Each iteration will have variables created for each field
#               requested.  The names of the variables will be of the form
#               'fieldprefix_fieldname' where fieldprefix will be the
#               tablename or a field prefix pass using the '-fieldprefix'
#               switch.
#
# Switches:
#   -fieldprefix fieldprefix  A prefix used instead of the tablename to
#                             create the variables for each field.
#
# Results:
#   None.
#
proc hetdb::for {args} {
  array set options {}
  while {[llength $args]} {
    switch -glob -- [lindex $args 0] {
      -fieldprefix {set args [lassign $args - options(fieldprefix)]}
      --      {set args [lrange $args 1 end] ; break}
      -*      {return -code error "unknown option: [lindex $args 0]"}
      default break
    }
  }
  if {[llength $args] != 4} {
    return -code error "wrong # args: should be \"for ?switches? db tablename fields body\""
  }

  lassign $args db tablename fields body
  if {[info exists options(fieldprefix)]} {
    set fieldprefix $options(fieldprefix)
  } else {
    set fieldprefix $tablename
  }

  if {![dict exists $db $tablename]} {
    return -code error "unknown table \"$tablename\" in database"
  }
  foreach row [dict get $db $tablename] {
    foreach field $fields {
      uplevel 1 [list set ${fieldprefix}_$field [MustDictGet $row $field]]
    }
    # Codes: 0 Normal return, 1 Error, 2 return command invoked
    #        3 break command invoked, 4 continue command invoked
    set retcode [catch {uplevel 1 $body} res]
    switch -- $retcode {
      0 -
      4       {}
      3       {return}
      default {return -code $retcode $res}
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
  if {![dict exists $db $tablename]} {
    return -code error "unknown table \"$tablename\" in database"
  }
  set tb [dict get $db $tablename]
  if {[catch {lsort -command $command $tb} res]} {
    return -code error $res
  }
  dict set db $tablename $res
}


# hetdb::validate
#
# Validate that a database is properly formed as are each of its tables.
# Each table must conform to any entries in the table '_tabledef'.
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
    if {$tablename eq "_tabledef"} {
      continue
    }
    set err [ValidateTable $tabledef $tablename $rows]
    if {$err ne ""} {
      return $err
    }
  }

  return {}
}


# Checks that table name contains only alpha-numeric characters and
# '_'.  If it begins with '_' then it can only be '_tabledef'.  It
# must not end with a '_'.
# Returns true if tablename is valid or false if not
proc hetdb::IsValidTablename {tablename} {
  set validSpecialNames {_tabledef}
  if {$tablename in $validSpecialNames} {
    return true
  }
  if {[string match {*_} $tablename]} {
    return false
  }
  if {[regexp -nocase {^[[:alnum:]][[:alnum:]_]*$} $tablename]} {
    return true
  }
  return false
}


# Checks that field name contains only alpha-numeric characters and
# '_'.  It must not begin or end with a '_'.
# Returns true if fieldname is valid or false if not
proc hetdb::IsValidFieldname {fieldname} {
  if {[string match {*_} $fieldname]} {
    return false
  }
  if {[regexp -nocase {^[[:alnum:]][[:alnum:]_]*$} $fieldname]} {
    return true
  }
  return false
}


# Checks that a table is properly formed and conforms to any definition
# in '_tabledef'
proc hetdb::ValidateTable {tabledef tablename rows} {
  if {![IsValidTablename $tablename]} {
    return "invalid table name \"$tablename\""
  }
  if {![string is list $rows]} {
    return "structure of table \"$tablename\" not valid"
  }
  if {![dict exists $tabledef $tablename]} {
    return "no entry for table \"$tablename\" in table \"_tabledef\""
  }
  set optional [MustDictGet $tabledef $tablename optional]
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
    set fields [dict keys $row]
    foreach mankey $mandatory {
      if {$mankey ni $fields} {
        return "mandatory field \"$mankey\" in table \"$tablename\" is missing"
      }
    }
    foreach field $fields {
      if {![IsValidFieldname $field]} {
        return "invalid field name \"$field\" in table \"$tablename\""
      }
      if {$field ni $mandatory && $field ni $optional} {
        return "extra field \"$field\" in table \"$tablename\""
      }
      if {$field in $unique} {
        set val [string trim [dict get $row $field]]
        if {[dict exists $uniques $field $val]} {
          return "field \"$field\" in table \"$tablename\" isn't unique"
        } else {
          dict set uniques $field $val 1
        }
      }
    }
    incr rowNum
  }

  return {}
}


# Return the '_tabledef' table as a dictionary using each name as a key
# The table is return as the first element of a list, the second entry
# is an error if present
proc hetdb::GetTabledef {db} {
  set ret [dict create]
  if {![dict exists $db _tabledef]} {
    return [list {} "table \"_tabledef\" is missing"]
  }
  set tabledefs [dict get $db _tabledef]
  set _tabledefTabledef {_tabledef {mandatory name optional {mandatory optional unique} unique name}}
  set err [ValidateTable $_tabledefTabledef _tabledef $tabledefs]
  if {$err ne ""} {
    return [list {} $err]
  }
  foreach tabledef $tabledefs {
    set tablename [dict get $tabledef name]
    if {$tablename eq "_tabledef"} {
      return [list {} "can't define \"_tabledef\" in table \"_tabledef\""]
    }
    set optional [MustDictGet $tabledef optional]
    set mandatory [MustDictGet $tabledef mandatory]
    foreach optionalField $optional {
      if {$optionalField in $mandatory} {
        return [list {} "field \"$optionalField\" in table \"$tablename\" can't be optional and mandatory"]
      }
    }
    dict set ret $tablename optional $optional
    dict set ret $tablename mandatory $mandatory
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
    return -code error "wrong # args: should be \"MustDictGet dictionaryValue ?key ...?\""
  }
  set keys $args
  if {[dict exists $dict {*}$keys]} {
    return [dict get $dict {*}$keys]
  }
  return {}
}


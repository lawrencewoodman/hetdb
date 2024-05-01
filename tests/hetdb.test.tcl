package require Tcl 8.5
package require tcltest
namespace import tcltest::*


set ThisScriptDir [file dirname [info script]]
set RootDir [file normalize [file join $ThisScriptDir ..]]
set FixturesDir [file normalize [file join $ThisScriptDir fixtures]]
set modules [lsort -decreasing [glob -directory $RootDir hetdb-*.tm]]
source [lindex $modules 0]


test read-1 {Check a valid database is loaded correctly} \
-body {
  set db [hetdb read [file join $FixturesDir complete.hetdb]]
  expr {$db ne ""}
} -result 1


test read-2 {Check raises error if can't load file} \
-body {
  set isErr [catch {hetdb read [file join $FixturesDir unknown.hetdb]} err]
  list $isErr [regsub {".*unknown.hetdb"} $err {"unknown.hetdb"}]
} -result {1 {couldn't open "unknown.hetdb": no such file or directory}}


test read-3 {Check raises error if outer db not valid dict} \
-body {
  set db [hetdb read [file join $FixturesDir outer_db_not_valid.hetdb]]
} -returnCodes {error} -result {outer structure of database not valid}


test read-4 {Check raises error if table not valid list} \
-body {
  set db [hetdb read [file join $FixturesDir table_not_valid.hetdb]]
} -returnCodes {error} -result {structure of table not valid, table: tag}


test read-5 {Check raises error if row not valid dict} \
-body {
  set db [hetdb read [file join $FixturesDir row_not_valid.hetdb]]
} -returnCodes {error} -result {structure of row not valid, table: link, row: 1}


test verify-1 {Check valid database is verified as correct} \
-setup {
  set db [hetdb read [file join $FixturesDir complete.hetdb]]
} -body {
  hetdb verify $db tabledef
} -result {true {}}


# TODO: Rename tabledef?
test verify-2 {Check 'unique' in tabledef identifies non unique fields and trims before comparing} \
-setup {
  set db [hetdb read [file join $FixturesDir non_unique.hetdb]]
} -body {
  hetdb verify $db tabledef
} -result {false {table: link, key isn't unique: url}}


# TODO: Rename tabledef?
test verify-3 {Check 'mandatory' in tabledef identifies missing fields} \
-setup {
  set db [hetdb read [file join $FixturesDir missing_mandatory.hetdb]]
} -body {
  hetdb verify $db tabledef
} -result {false {table: link, missing key: title}}


test for-1 {Check calls body script for each row of table} \
-setup {
  set db [hetdb read [file join $FixturesDir complete.hetdb]]
} -body {
  set rows [list]
  hetdb for $db tag tag {
    lappend rows $tag
  }
  set rows
} -result [list {name cooking title {How to Cook} main true} \
                {name mechanics title {How to Make Things} main true} \
                {name article title {An Article} main false}]


# Used by for-2 to check error handled
proc Hetdb_for_with_error {db tablename} {
  set compLevel [info level]
  set rowNum 0
  set isErr [catch {
    hetdb for $db tag tag {
      if {$rowNum == 2} {
        error "this is an error from for-2"
      }
      incr rowNum
    }
  } err options]
  list $isErr $err [dict get $options -level] $compLevel
}

test for-2 {Check error is handled within body script} \
-setup {
  set db [hetdb read [file join $FixturesDir complete.hetdb]]
} -body {
  {*}Hetdb_for_with_error $db tag
} -result {1 {this is an error from for-2} 0 1}


# Used by for-3 to check return handled
proc Hetdb_for_with_return {db tablename} {
  set compLevel [info level]
  set rowNum 0
  set code [catch {
    hetdb for $db tag tag {
      if {$rowNum == 2} {
        return "this is a return from for-3"
      }
      incr rowNum
    }
  } res options]
  list $code $res [dict get $options -level] $compLevel
}


test for-3 {Check return is handled within body script} \
-setup {
  set db [hetdb read [file join $FixturesDir complete.hetdb]]
} -body {
  {*}Hetdb_for_with_return $db tag
} -result {2 {this is a return from for-3} 1 1}


test for-4 {Check break is handled within body script} \
-setup {
  set db [hetdb read [file join $FixturesDir complete.hetdb]]
} -body {
  set rows [list]
  set rowNum 0
  hetdb for $db tag tag {
    if {$rowNum == 2} {
      break
    }
    lappend rows $tag
    incr rowNum
  }
  set rows
} -result [list {name cooking title {How to Cook} main true} \
                {name mechanics title {How to Make Things} main true}]


test for-5 {Check continue is handled within body script} \
-setup {
  set db [hetdb read [file join $FixturesDir complete.hetdb]]
} -body {
  set rows [list]
  set rowNum 0
  hetdb for $db tag tag {
    incr rowNum
    if {$rowNum == 2} {
      continue
    }
    lappend rows $tag
  }
  set rows
} -result [list {name cooking title {How to Cook} main true} \
                {name article title {An Article} main false}]


test forfields-1 {Check calls body script for each row of table} \
-setup {
  set db [hetdb read [file join $FixturesDir complete.hetdb]]
} -body {
  set rows [list]
  hetdb forfields $db tag "tag_" {name title} {
    lappend rows [list $tag_name $tag_title]
  }
  set rows
} -result [list {cooking {How to Cook}} \
                {mechanics {How to Make Things}} \
                {article {An Article}}]


test forfields-2 {Check can handle field missing in row} \
-setup {
  set db [hetdb read [file join $FixturesDir complete_extra_field_in_tag.hetdb]]
} -body {
  set rows [list]
  hetdb forfields $db tag "tag_" {name title priority} {
    lappend rows [list $tag_name $tag_title]
  }
  set rows
} -returnCodes {error} -result {unknown field in row: priority}

#
# Used by forfields-3 to check error handled
proc Hetdb_forfields_with_error {db tablename} {
  set compLevel [info level]
  set rowNum 0
  set isErr [catch {
    hetdb forfields $db tag "tag_" {name title} {
      if {$rowNum == 2} {
        error "this is an error from forfields-3"
      }
      incr rowNum
    }
  } err options]
  list $isErr $err [dict get $options -level] $compLevel
}

test forfields-3 {Check error is handled within body script} \
-setup {
  set db [hetdb read [file join $FixturesDir complete.hetdb]]
} -body {
  {*}Hetdb_forfields_with_error $db tag
} -result {1 {this is an error from forfields-3} 0 1}


# Used by forfields-4 to check return handled
proc Hetdb_forfields_with_return {db tablename} {
  set compLevel [info level]
  set rowNum 0
  set code [catch {
    hetdb forfields $db tag "tag_" {name title} {
      if {$rowNum == 2} {
        return "this is a return from forfields-4"
      }
      incr rowNum
    }
  } res options]
  list $code $res [dict get $options -level] $compLevel
}

test forfields-4 {Check return is handled within body script} \
-setup {
  set db [hetdb read [file join $FixturesDir complete.hetdb]]
} -body {
  {*}Hetdb_forfields_with_return $db tag
} -result {2 {this is a return from forfields-4} 1 1}


test forfields-5 {Check break is handled within body script} \
-setup {
  set db [hetdb read [file join $FixturesDir complete.hetdb]]
} -body {
  set rows [list]
  set rowNum 0
  hetdb forfields $db tag "tag_" {name title} {
    if {$rowNum == 2} {
      break
    }
    lappend rows [list $tag_name $tag_title]
    incr rowNum
  }
  set rows
} -result [list {cooking {How to Cook}} \
                {mechanics {How to Make Things}}]


test forfields-6 {Check continue is handled within body script} \
-setup {
  set db [hetdb read [file join $FixturesDir complete.hetdb]]
} -body {
  set rows [list]
  set rowNum 0
  hetdb forfields $db tag "tag_" {name title} {
    incr rowNum
    if {$rowNum == 2} {
      continue
    }
    lappend rows [list $tag_name $tag_title]
  }
  set rows
} -result [list {cooking {How to Cook}} \
                {article {An Article}}]


# Used by sort-1 to compare entries in the tag table
proc CompareTag {a b} {
  string compare [dict get $a name] [dict get $b name]
}

test sort-1 {Check will return a sorted table} \
-setup {
  set db [hetdb read [file join $FixturesDir complete.hetdb]]
} -body {
  set sortedDB [hetdb sort $db tag CompareTag]
  set rows [list]
  hetdb for $sortedDB tag tag {
    lappend rows $tag
  }
  list [expr {$db ne $sortedDB}] $rows
} -result [list 1 [list \
             {name article title {An Article} main false} \
             {name cooking title {How to Cook} main true} \
             {name mechanics title {How to Make Things} main true}]]



cleanupTests


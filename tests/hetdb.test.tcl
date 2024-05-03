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
  hetdb read [file join $FixturesDir outer_db_not_valid.hetdb]
} -returnCodes {error} -result {outer structure of database not valid}


test read-4 {Check raises error if table not valid list} \
-body {
  hetdb read [file join $FixturesDir table_not_valid.hetdb]
} -returnCodes {error} -result {structure of table "tag" not valid}


test read-5 {Check raises error if row not valid dict} \
-body {
  hetdb read [file join $FixturesDir row_not_valid.hetdb]
} -returnCodes {error} -result {structure of row 1 in table "link" not valid}


test read-6 {Check raises error if _tabledef not valid list} \
-body {
  hetdb read [file join $FixturesDir _tabledef_not_valid.hetdb]
} -returnCodes {error} -result {structure of table "_tabledef" not valid}


test read-7 {Check raises error if 'name' missing in _tabledef} \
-body {
  hetdb read [file join $FixturesDir _tabledef_missing_name.hetdb]
} -returnCodes {error} -result {mandatory field "name" in table "_tabledef" is missing}


test read-8 {Check raises error if 'name' isn't unique in _tabledef} \
-body {
  hetdb read [file join $FixturesDir _tabledef_non_unique_name.hetdb]
} -returnCodes {error} -result {field "name" in table "_tabledef" isn't unique}


test read-9 {Check raises error if '_tabledef' used as name _tabledef} \
-body {
  hetdb read [file join $FixturesDir _tabledef__tabledef_name.hetdb]
} -returnCodes {error} -result {can't define "_tabledef" in table "_tabledef"}


test read-10 {Check 'unique' in _tabledef identifies non unique fields and trims before comparing} \
-body {
  hetdb read [file join $FixturesDir non_unique.hetdb]
} -returnCodes {error} -result {field "url" in table "link" isn't unique}


test read-11 {Check 'mandatory' in _tabledef identifies missing fields} \
-body {
  hetdb read [file join $FixturesDir missing_mandatory.hetdb]
} -returnCodes {error} -result {mandatory field "title" in table "link" is missing}


test read-12 {Check raises error if a table name begins with '_' and isn't _tabledef} \
-body {
  hetdb read [file join $FixturesDir invalid_special_table_name.hetdb]
} -returnCodes {error} -result {invalid table name "_something"}


test read-13 {Check raises error if a table name is invalid} \
-body {
  hetdb read [file join $FixturesDir invalid_table_name.hetdb]
} -returnCodes {error} -result {invalid table name "some-thing"}


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
} -returnCodes {error} -result {field "priority" missing from row}

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


package require Tcl 8.5
package require tcltest
namespace import tcltest::*


set ThisScriptDir [file dirname [info script]]
set RootDir [file normalize [file join $ThisScriptDir ..]]
set FixturesDir [file normalize [file join $ThisScriptDir fixtures]]
set modules [lsort -decreasing [glob -directory $RootDir hetdb-*.tm]]
source [lindex $modules 0]


# The following tests for read should be kept in sync with the
#  validate tests below
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


test read-14 {Check raises error if a field name is invalid} \
-body {
  hetdb read [file join $FixturesDir invalid_field_name.hetdb]
} -returnCodes {error} -result {invalid field name "some-thing" in table "link"}


# The following tests for validate should be kept in sync with the read tests
# above therefore validate-2 isn't present below
test validate-1 {Check a valid database returns a blank string} \
-setup {
    set filename [file join $FixturesDir complete.hetdb]
    set fd [open $filename r]
    set db [::read $fd]
    close $fd
 } -body {
  hetdb validate $db
} -result {}


test validate-3 {Check raises error if outer db not valid dict} \
-setup {
    set filename [file join $FixturesDir outer_db_not_valid.hetdb]
    set fd [open $filename r]
    set db [::read $fd]
    close $fd
 } -body {
  hetdb validate $db
} -result {outer structure of database not valid}


test validate-4 {Check raises error if table not valid list} \
-setup {
    set filename [file join $FixturesDir table_not_valid.hetdb]
    set fd [open $filename r]
    set db [::read $fd]
    close $fd
 } -body {
  hetdb validate $db
} -result {structure of table "tag" not valid}


test validate-5 {Check raises error if row not valid dict} \
-setup {
    set filename [file join $FixturesDir row_not_valid.hetdb]
    set fd [open $filename r]
    set db [::read $fd]
    close $fd
 } -body {
  hetdb validate $db
} -result {structure of row 1 in table "link" not valid}


test validate-6 {Check raises error if _tabledef not valid list} \
-setup {
    set filename [file join $FixturesDir _tabledef_not_valid.hetdb]
    set fd [open $filename r]
    set db [::read $fd]
    close $fd
 } -body {
  hetdb validate $db
} -result {structure of table "_tabledef" not valid}


test validate-7 {Check raises error if 'name' missing in _tabledef} \
-setup {
    set filename [file join $FixturesDir _tabledef_missing_name.hetdb]
    set fd [open $filename r]
    set db [::read $fd]
    close $fd
 } -body {
  hetdb validate $db
} -result {mandatory field "name" in table "_tabledef" is missing}


test validate-8 {Check raises error if 'name' isn't unique in _tabledef} \
-setup {
    set filename [file join $FixturesDir _tabledef_non_unique_name.hetdb]
    set fd [open $filename r]
    set db [::read $fd]
    close $fd
 } -body {
  hetdb validate $db
} -result {field "name" in table "_tabledef" isn't unique}


test validate-9 {Check raises error if '_tabledef' used as name _tabledef} \
-setup {
    set filename [file join $FixturesDir _tabledef__tabledef_name.hetdb]
    set fd [open $filename r]
    set db [::read $fd]
    close $fd
 } -body {
  hetdb validate $db
} -result {can't define "_tabledef" in table "_tabledef"}


test validate-10 {Check 'unique' in _tabledef identifies non unique fields and trims before comparing} \
-setup {
    set filename [file join $FixturesDir non_unique.hetdb]
    set fd [open $filename r]
    set db [::read $fd]
    close $fd
 } -body {
  hetdb validate $db
} -result {field "url" in table "link" isn't unique}


test validate-11 {Check 'mandatory' in _tabledef identifies missing fields} \
-setup {
    set filename [file join $FixturesDir missing_mandatory.hetdb]
    set fd [open $filename r]
    set db [::read $fd]
    close $fd
 } -body {
  hetdb validate $db
} -result {mandatory field "title" in table "link" is missing}


test validate-12 {Check raises error if a table name begins with '_' and isn't _tabledef} \
-setup {
    set filename [file join $FixturesDir invalid_special_table_name.hetdb]
    set fd [open $filename r]
    set db [::read $fd]
    close $fd
 } -body {
  hetdb validate $db
} -result {invalid table name "_something"}


test validate-13 {Check raises error if a table name is invalid} \
-setup {
  set filename [file join $FixturesDir invalid_table_name.hetdb]
  set fd [open $filename r]
  set templatedb [::read $fd]
  close $fd
  # A list of table names to switch some-thing for to test against
  set testTablenames {
    some-thing
    _tabledef
    _borris
    a
    a_b
    hello_goodbye_again
    a_
    today_is_
  }
 } -body {
  set got [list]
  foreach testname $testTablenames {
    set db [string map [list some-thing $testname] $templatedb]
    lappend got [hetdb validate $db]
  }
  set got
} -result [list {invalid table name "some-thing"} {} \
                {invalid table name "_borris"} {} {} {} \
                {invalid table name "a_"} \
                {invalid table name "today_is_"}]


test validate-14 {Check raises error if a field name is invalid} \
-setup {
    set filename [file join $FixturesDir invalid_field_name.hetdb]
    set fd [open $filename r]
    set templatedb [::read $fd]
    close $fd
  # A list of field names to switch some-thing for to test against
  set testTablenames {
    some-thing
    _tabledef
    _borris
    a
    a_b
    hello_goodbye_again
    a_
    today_is_
  }
 } -body {
  set got [list]
  foreach testname $testTablenames {
    set db [string map [list some-thing $testname] $templatedb]
    lappend got [hetdb validate $db]
  }
  set got
} -result [list {invalid field name "some-thing" in table "link"} \
                {invalid field name "_tabledef" in table "link"} \
                {invalid field name "_borris" in table "link"} {} {} {} \
                {invalid field name "a_" in table "link"} \
                {invalid field name "today_is_" in table "link"}]


test for-1 {Check calls body script for each row of table} \
-setup {
  set db [hetdb read [file join $FixturesDir complete.hetdb]]
} -body {
  set rows [list]
  hetdb for $db tag {name title} tag {
    lappend rows $tag
  }
  set rows
} -result [list {name cooking title {How to Cook}} \
                {name mechanics title {How to Make Things}} \
                {name article title {An Article}}]


test for-2 {Check can handle field missing in row} \
-setup {
  set db [hetdb read [file join $FixturesDir complete_extra_field_in_tag.hetdb]]
} -body {
  set rows [list]
  hetdb for $db tag {name title priority} tag {
    lappend rows [dict values $tag]
  }
  set rows
} -returnCodes {error} -result {field "priority" missing from row}


# Used by for-3 to check error handled
proc Hetdb_for_with_error {db tablename} {
  set compLevel [info level]
  set rowNum 0
  set isErr [catch {
    hetdb for $db tag {name title} tag {
      if {$rowNum == 2} {
        error "this is an error from for-3"
      }
      incr rowNum
    }
  } err options]
  list $isErr $err [dict get $options -level] $compLevel
}

test for-3 {Check error is handled within body script} \
-setup {
  set db [hetdb read [file join $FixturesDir complete.hetdb]]
} -body {
  {*}Hetdb_for_with_error $db tag
} -result {1 {this is an error from for-3} 0 1}


# Used by for-4 to check return handled
proc Hetdb_for_with_return {db tablename} {
  set compLevel [info level]
  set rowNum 0
  set code [catch {
    hetdb for $db tag {name title} tag {
      if {$rowNum == 2} {
        return "this is a return from for-4"
      }
      incr rowNum
    }
  } res options]
  list $code $res [dict get $options -level] $compLevel
}

test for-4 {Check return is handled within body script} \
-setup {
  set db [hetdb read [file join $FixturesDir complete.hetdb]]
} -body {
  {*}Hetdb_for_with_return $db tag
} -result {2 {this is a return from for-4} 1 1}


test for-5 {Check break is handled within body script} \
-setup {
  set db [hetdb read [file join $FixturesDir complete.hetdb]]
} -body {
  set rows [list]
  set rowNum 0
  hetdb for $db tag {name title} tag {
    if {$rowNum == 2} {
      break
    }
    lappend rows $tag
    incr rowNum
  }
  set rows
} -result [list {name cooking title {How to Cook}} \
                {name mechanics title {How to Make Things}}]


test for-6 {Check continue is handled within body script} \
-setup {
  set db [hetdb read [file join $FixturesDir complete.hetdb]]
} -body {
  set rows [list]
  set rowNum 0
  hetdb for $db tag {name title} tag {
    incr rowNum
    if {$rowNum == 2} {
      continue
    }
    lappend rows $tag
  }
  set rows
} -result [list {name cooking title {How to Cook}} \
                {name article title {An Article}}]


test for-7 {Check will raise an error if a table doesn't exist} \
-setup {
  set db [hetdb read [file join $FixturesDir complete.hetdb]]
} -body {
  hetdb for $db unknown {name title} tag {
  }
} -returnCodes {error} -result {unknown table "unknown" in database}


test for-8 {Check that the order of fiels is used in the row return} \
-setup {
  set db [hetdb read [file join $FixturesDir complete.hetdb]]
} -body {
  set rows [list]
  hetdb for $db tag {title name} tag {
    lappend rows $tag
  }
  set rows
} -result [list {title {How to Cook} name cooking} \
                {title {How to Make Things} name mechanics} \
                {title {An Article} name article}]


test for-9 {Check that * for fields returns all fields} \
-setup {
  set db [hetdb read [file join $FixturesDir complete.hetdb]]
} -body {
  set rows [list]
  hetdb for $db tag {*} tag {
    lappend rows $tag
  }
  set rows
} -result [list {name cooking title {How to Cook} main true} \
                {name mechanics title {How to Make Things} main true} \
                {name article title {An Article} main false}]


test for-10 {Check uses tablename as varname if latter not supplied} \
-setup {
  set db [hetdb read [file join $FixturesDir complete.hetdb]]
} -body {
  set rows [list]
  hetdb for $db tag {name title} {
    lappend rows $tag
  }
  set rows
} -result [list {name cooking title {How to Cook}} \
                {name mechanics title {How to Make Things}} \
                {name article title {An Article}}]


test for-11 {Check returns an error if not enough arguments supplied} \
-setup {
  set db [hetdb read [file join $FixturesDir complete.hetdb]]
} -body {
  hetdb for $db tag {
  }
} -returnCodes error -result {wrong # args: should be "for db tablename fields ?varname? body"}


test for-12 {Check returns an error if too many arguments supplied} \
-setup {
  set db [hetdb read [file join $FixturesDir complete.hetdb]]
} -body {
  hetdb for $db tag {name title} tag fred {
  }
} -returnCodes error -result {wrong # args: should be "for db tablename fields ?varname? body"}


# Used by sort-1 and sort-2 to compare entries in the tag table
proc CompareTag {a b} {
  string compare [dict get $a name] [dict get $b name]
}


test sort-1 {Check will return a sorted table} \
-setup {
  set db [hetdb read [file join $FixturesDir complete.hetdb]]
} -body {
  set sortedDB [hetdb sort $db tag CompareTag]
  set rows [list]
  hetdb for $sortedDB tag {*} tag {
    lappend rows $tag
  }
  list [expr {$db ne $sortedDB}] $rows
} -result [list 1 [list \
             {name article title {An Article} main false} \
             {name cooking title {How to Cook} main true} \
             {name mechanics title {How to Make Things} main true}]]


test sort-2 {Check will raise an error if a table doesn't exist} \
-setup {
  set db [hetdb read [file join $FixturesDir complete.hetdb]]
} -body {
  hetdb sort $db unknown CompareTag
} -returnCodes {error} -result {unknown table "unknown" in database}


# Used by sort-3 to compare entries in a table but raises and error
proc CompareTag_with_error {a b} {
  error "this is an error"
}


test sort-3 {Check will raise an error if the command raises an error} \
-setup {
  set db [hetdb read [file join $FixturesDir complete.hetdb]]
} -body {
  hetdb sort $db tag CompareTag_with_error
} -returnCodes {error} -result {this is an error}


cleanupTests


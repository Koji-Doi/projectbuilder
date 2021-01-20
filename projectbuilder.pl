#!/usr/bin/env perl
use Mojolicious::Lite;
use Cwd;
use Time::Piece;
use File::Path;
use File::Copy;
use Data::Dumper;
use utf8;

binmode STDOUT, ':utf8';

plugin 'DefaultHelpers';
# Documentation browser under "/perldoc"                                                                                                      
plugin 'PODRenderer';
{ # display 日本語 properly on dumper                                                                                                         
  package Data::Dumper ;
    no warnings 'redefine' ;
  *Data::Dumper::qquote = sub { return shift } ;
  $Data::Dumper::Useperl = 1 ;
}
our %extopt;

under sub{
  $extopt{wd} = cwd();
  $extopt{source} = "$extopt{wd}/_source";
  $extopt{layout} = "$extopt{wd}/_layout";
  $extopt{out}    = "$extopt{wd}/_output";

};

get '/' => sub {
  my $c = shift;
  $c->render(template => 'index');
};

# edit/create proj
any '/edit' => sub{
  my $c = shift;
  my $param = $c->req->params->to_hash;
  my $pid = $param->{pid}; # project ID
  my $is_new; # flag indicating if the project is new
  my %submitdata;
  foreach my $key (%$param){
    $key=~/^_/ and next;
    (defined $param->{$key}) or next;
    ($param->{$key}=~/\S/)   or next;
    my $key1=$key;
    $key1=~s/^\d+//g;
    $submitdata{$key1} = $param->{$key};
  }
  ($submitdata{pid}) and $pid=$submitdata{pid}; # overwrite pid
 
  # create new project
  (defined $pid) or ($pid, $is_new) = (localtime->strftime("proj%y%m%d"), 1);

  my $src = "$extopt{source}/$pid.html";
  (-f $src) or $c->redirect("/error");


  ($submitdata{layout}) or $submitdata{layout}="project.html";

  my $status = ($param->{_project_entry_submit} eq 'Submit')?'submit':'new';

  if($status eq 'submit'){ # after form submission
    # save source file
    (-d $extopt{source}) or mkpath($extopt{source});
    my $srcfile = $extopt{source}."/$pid.md";
    my $i=0;
    if(-f $srcfile){
      my $srcfile2 = $extopt{source}."/${pid}-".localtime->strftime("%Y%m%d_%H%M%S")."md";
      print "backup: $srcfile -> $srcfile2\n";
      copy $srcfile, $srcfile2;
    }
    print "new source file = $srcfile.\n";
    open(my $fho, '>:utf8', $srcfile) or die;
    print {$fho} "---\n";
    foreach my $k (sort keys %submitdata){
      printf {$fho} "%s: %s\n", $k, $submitdata{$k};
    }
    print {$fho} "---\n";
    close $fho;
  }

  $c->render(template => 'enter', pid=>$param->{pid}, status=>$status, submitdata=>\%submitdata);
};

# list projects
any '/list' => sub {
  my $c = shift;
  my $param = $c->req->params->to_hash;
print Dumper $param;
  $c->render(template => 'list');
};

app->secrets(['wefefeffgg]33']);
app->start;

__DATA__

@@ index.html.ep
% layout 'default';
% title 'Welcome';

<h1>Project Builder</h1>

<ul>
<li><a href="<%= url_for("/edit") %>"</a>make new project</li>
<li><a href="<%= url_for("/list") %>"</a>list</li>
</ul>
<a href="<%= url_for '/create' %>"crea</a>

@@ enter.html.ep
% layout 'default';
% title 'enter';
<%
sub f{
  my($fldname, $type, $opt) = @_;
  $type = $type || 'text';
  if($type eq 'textarea' or $type eq 'a'){
    return(qq!<textarea style="width:95%; height:95%; margin:0px;" rows="5" name="$fldname"></textarea>!);
  }else{
    return(qq!<input style="width:95%; height:95%; margin:0px;" type="$type" name="$fldname">!);
  }
}
my($pid, $status, $submitdata) = map {stash($_)} qw/pid status submitdata/;

%>

<h1>Project Entry</h1>

% if($status eq 'submit'){
  submitted.
<dl>
  % foreach my $key (sort keys %$submitdata){
  %  my $key1=$key; $key1=~s/^\d+//;
    <dt><%= $key1 %></dt><dd><%= $submitdata->{$key} %></dd>
  % }
</dl>
% }else{
<form method="post" action="<%= url_for('/edit') %>">
<table>
<tr><th colspan="2" class="tbl_1">Project ID</th><td class="tbl_2"><%== f('00projectid') %></td></tr>
<tr><th colspan="2">Brief Description</th><td><%== f('01desc', 'a'       ) %></td></tr>
<tr><th colspan="2">Project Builder  </th><td><%== f('02builer'          ) %></td></tr>
<tr><th colspan="2">Client           </th><td><%== f('03client'          ) %></td></tr>
<tr><th colspan="2">Related projects </th><td><%== f('04relproj'         ) %></td></tr>
<tr><th colspan="2"><b>Deadline</b>  </th><td><%== f('05deadline', 'date') %></td></tr>

<ul>
<tr><th rowspan="20">Tasks</th><td class="nullcell">001</td><td class="nullcell"><%== f('06task001', 'textarea') %></td></tr>
% foreach my $n ('002'..'010'){
<tr><td class="nullcell"><%= $n %></td><td class="nullcell"> <%== f("06task$n", 'textarea') %></td></tr>
% }
</ul>
</td></tr>
</table>
%= submit_button "Submit", id=>'_project_entry_submit', name=>'_project_entry_submit'
</form>
%}

@@ list.html.ep
% layout 'default';
% title 'list';

@@ navbar.html.ep
% my $langswitch = stash('langswitch');
<nav>
  [<a href="<%= url_for("/?lang=$clang") %>">Start page</a>]&nbsp;[<a href="<%= url_for("/list?lang=$clang") %>">Project list</a>]
</nav>

@@ layouts/default.html.ep
<% 
  my $conf       = stash('conf')  || stash('extopt');
  my $clang      = stash('clang') || $conf->{conf}{clang} || 'ja';
  my $layout     = stash('layoutfile'); 
  my $source     = stash('srcfile');
  my $langswitch = stash('langswitch');
# copy source file to create multilingual sources
%>

<!DOCTYPE html>
<html>
  <head><title><%= title %></title>
  <link rel="stylesheet" type="text/css" href="https://unpkg.com/mvp.css">
  <style>
  body{
    max-width: 1000px;
  }
  main{
    text-align: center;
    max-width: 800px;
  }
  .nullcell{
    background-color: white;
    text-align: left;
  }
  table {
    table-layout: fixed;
    width: 100%;
  }
  table,th,td {
    border: 1px solid #bbb;
  }
  .tbl_1 {
    width: 10%;
  }
  .tbl_2 {
    width: 90%;
  }
  nav{
    text-align: left;
    border-top: 1px solid;
    border-bottom: 1px solid;
    margin: 10px;
  }
  </style>
  </head>
  <body>
  <main>
%= include 'navbar', source=>$source, layout=>$layout, conf=>$conf, clang=>$clang, langswitch=>$langswitch;
<%= content %>
%= include 'navbar', source=>$source, layout=>$layout, conf=>$conf, clang=>$clang, langswitch=>$langswitch;
  </main>
  </body>
</html>

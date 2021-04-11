#!/usr/bin/env perl
use Mojolicious::Lite;
use Cwd;
use Time::Piece;
use File::Path;
use File::Copy;
use Data::Dumper;
use utf8;
use Cwd;

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
  $extopt{date}   = localtime->ymd('');
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
  my %initdata; # data from existing project data file (_source/*.md)
  my $is_new; # flag indicating if the project is new
  my %submitdata;
  foreach my $key (%$param){
    $key=~/^_/ and next;
    (defined $param->{$key}) or next;
    ($param->{$key}=~/\S/)   or next;
    my $key1=$key;
    ($key1) and $key1=~s/^\d+//g;
    $submitdata{$key1} = $param->{$key};
  }
  ($submitdata{pid}) and $pid=$submitdata{pid}; # overwrite pid

  # create new project
  if(defined $pid){
    my $mdfile = "_source/$pid.md";
    if(-f $mdfile){
      open(my $fhi, '<:utf8', $mdfile) or die "$mdfile not accessible";
      while(<$fhi>){
        s/[\n\r]*$//;
        my($k,$v) = /(.*)\s*:\s*(.*)/;
        ($k) and $k=~s/^\d+//;
        (defined $k) and $initdata{$k} = $v;
      }
print "initdata: ",Dumper %initdata;
      close $fhi;
    }else{
      $c->render('error', filenotfound=>$mdfile);
      return;
    }
  }else{
    ($pid, $is_new) = (localtime->strftime("proj%y%m%d"), 1);
  }
  ($submitdata{layout}) or $submitdata{layout}="project.html";

  my $status = (defined $param->{_project_entry_submit} and $param->{_project_entry_submit} eq 'Submit')?'submit':'newproj';

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
print "init=", Dumper %initdata;
  $c->render(template => 'edit', pid=>$pid, stat1=>$status, submitdata=>\%submitdata, initdata=>\%initdata);
};

# list projects
any '/list' => sub {
  my $c = shift;
  my $param = $c->req->params->to_hash;
  my $plist;
  foreach my $file (<$extopt{source}/*.md>){
    my %data;
    open(my $fhi, '<:utf8', $file);
    while(<$fhi>){
      s/[\n\r]*$//;
      my($k, $v) = /(.*)\s*:\s*(.*)/;
      ($k) or next;
      $data{$k} = $v;
    }
    $data{file} = $file;
    map{ (defined $data{$_}) or $data{$_}=''; } qw/ddate deadline builder desc pid/;
    ($data{projectid}) and $data{pid} = $data{projectid};
    $plist->{$data{pid}} = \%data;
  }
  $c->render(template => 'list', plist=>$plist);
};

any '/error' => sub{
  my $c = shift;
  my $p = $c->req->params->to_hash;
  $c->render('error', p=>$p);
};


app->secrets(['wxxefefeffgg]33']);
app->start;

__DATA__

@@ index.html.ep
% layout 'default';
% title 'Welcome';

<h1>Project Builder</h1>

<ul>
<li><a href="<%= url_for("/edit") %>">make new project</a></li>
<li><a href="<%= url_for("/list") %>">list</a></li>
</ul>

@@ edit.html.ep
% layout 'default';
% title 'edit';
<%
use Time::Piece;
my($pid, $status)          = map {stash($_) || ''}  qw/pid stat1/;
my($submitdata, $initdata) = map {stash($_) || {} } qw/submitdata initdata/;
$initdata->{'pid'} = $pid;
my $ddate = $initdata->{ddate} || localtime->ymd('-');
print $initdata->{ddate}, ">>ddate>> $ddate\n";
%>

<h1>Project Entry</h1>

% if($status eq 'submit'){ # edit ended
  submitted.<br>
<table border="1" style="text-align:left;">
% foreach my $key (sort keys %$submitdata){
%  my $key1=$key; $key1=~s/^\d+//;
    <tr><th><%= $key1 %></th><td><%= $submitdata->{$key} %></td></tr>
% }
</table>
% }else{ # edit continued
<form method="post" action="<%= url_for('/edit') %>">
%= hidden_field 'ddate' => $ddate
<table class="entryform">
%= include 'p_item', name=>'pid', label=>'Project ID', value=>$initdata->{pid}, desc=>"プロジェクトID。半角英数文字からなる文字列。ただし必ず日付を入れて設定すること", ph=>'20210401mouse', pattern=>'^\w*\d\w*$';
 <tr>
   <th colspan="2" class="tbl_1" placeholder="20220401mouse"><span title="プロジェクト起案日">Drafting Date</span></th>
   %=t 'td', $ddate
 </tr>
%= include 'p_item', name=>'01desc',     label=>'Brief Description', value=>$initdata->{desc}, type=>'a', desc=>'プロジェクトの目標・進め方を１００字程度で簡潔に記す', ph=>'マウスの10サンプルについてRNA-Seq解析を行ない、スプライシングバリアントの解析結果のグラフ、NAプロット、PCA、ヒートマップの図を作成する。';
%= include 'p_item', name=>'02builder',  label=>'Project Builder',   value=>$initdata->{builder}, desc=>'プロジェクト設定者の名前';
%= include 'p_item', name=>'03client',   label=>'Client',            value=>$initdata->{client}, desc=>'発注主', ph=>'〇〇大学××研究室', init=>$initdata;
%= include 'p_item', name=>'04relproj',  label=>'Related Projects',  value=>$initdata->{relproj}, desc=>'過去のプロジェクトの続きであるなら、そのプロジェクトのIDを列挙';
%= include 'p_item', name=>'05deadline', label=>'Deadline',          value=>$initdata->{deadline}, type=>'date', desc=>'データ納品締め切り日';
%= include 'p_item', name=>'06input',    label=>'Input',             value=>$initdata->{deadline}, type=>'a',    desc=>'依頼元から提供されたファイルの置き場所やファイル名。あるいはダウンロード先のURL';
%= include 'p_item', name=>'07output',   label=>'Output',            value=>$initdata->{deadline}, type=>'a',    desc=>'提出すべきファイルや文書のリスト';

 <tr><th rowspan="20"><span title="作業手順。１０ステップに分けて記す">Tasks</span></th><td class="nullcell">001</td><td class="nullcell">
  <textarea style="width:95%; height:95%; margin:0px;", name='06task001'><%= $initdata->{'task001'} %></textarea>
 </td></tr>
% foreach my $n ('002'..'010'){
 <tr><td class="nullcell"><%= $n %></td><td class="nullcell">
  <textarea style="width:95%; height:95%; margin:0px;", name='<%= "06task$n" %>'><%= $initdata->{"task$n"} %></textarea>
 </td></tr>
% }
</td></tr>
</table>
%= submit_button "Submit", id=>'_project_entry_submit', name=>'_project_entry_submit'
</form>
%}

@@ p_item.html.ep
<%
#my($desc, $value) = map {stash($_)} qw/desc value/;
my %par = (style=>"width:95%; height:95%; margin:0px;");
map { defined stash($_) and $par{$_}=stash($_) } qw/desc value name label ph type pattern min max/;
($par{type}) or $par{type}='text';
($par{ph})  and $par{placeholder}=$par{ph};
(defined $par{type}) or $par{type}='';
%>
 <tr>
  <th colspan="2" class="tbl_1">
%=t 'span', title=>$par{desc}, $par{label}
  </th>
  <td>
% if($par{type} eq 'textarea' or $par{type} eq 'a'){
%=t 'textarea', %par, $par{value}
%}else{
%=t 'input', %par
%}
  </td>
 </tr>

@@ list.html.ep
% layout 'default';
% title 'list';
<%
  my($plist, $from_ddate, $until_ddate, $from_deadline, $until_deadline, $client, $desc)
     = map {stash($_)} qw/plist f_ddate u_ddate f_deadline u_deadline client desc/;
  my @colnames = qw/ddate deadline builder desc/;
%>
<table>
<tr>
%= t 'th', $_ foreach ('pid', @colnames) 
</tr>
% foreach my $pid (sort keys %$plist){
 <tr>
  <th> <%= link_to $pid => "/edit?pid=$pid" %></th>
%= t 'td', $plist->{$pid}{$_} foreach (@colnames)
 </tr>
% }
</table>

@@ error.html.ep
<%
  my($filenotfound) = map {stash($_)} qw/filenotfound/;
print ">>> filenotfound=$filenotfound\n";
%>

<h1>Error</h1>
% if(defined $filenotfound){
%= t 'p', "$filenotfound not found";
% }

@@ navbar.html.ep
% my $langswitch = stash('langswitch');
% my $clang="ja";
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
  <head>
  <title><%= title %></title>
  <!-- link rel="stylesheet" href="https://unpkg.com/mvp.css" -->
  <%= stylesheet 'css/mvp.css' %>
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
  table.entryform {
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

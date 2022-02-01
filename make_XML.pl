use strict;
use warnings;
use Template;
use DBI;
use Net::OpenSSH;
use Config::Simple;
use DateTime;
use File::Spec;
use File::Path;
use File::Basename;
use Data::Dumper;

my %config; 
Config::Simple->import_from( "sql_connection.ini", \%config );
my %hubs; 
Config::Simple->import_from( "shipping_hubs.ini", \%hubs );
#ssh host
my $total_time_start = time();

#database name
my $db = $config{'PSQL.db'};
#database hostname
my $host = $config{'PSQL.host'};
#database port
my $port = $config{'PSQL.port'};
my $ssh_db_port = $config{'SSH.db_port'};
my $key_name = $config{'SSH.keyname'};
my $ssh_host = $config{'SSH.host'};
my $output_folder = ".";
my $ssh;
print Dumper \%config;
#set up SSH tunnel
if( $config{'SSH.enabled'} eq 'true'){
    $ssh = Net::OpenSSH->new($ssh_host,key_path => $key_name, master_opts => [-L => "127.0.0.1:$port:localhost:$ssh_db_port"]) or die;
}
my $dsn = "dbi:Pg:dbname='$db';host='$host';port='$port';";
#database username
my $usr = $config{'PSQL.username'};
# database password
my $pwrd = $config{'PSQL.password'};

my $dbh =DBI->connect($dsn, $usr, $pwrd, {AutoCommit => 0}) or die ( "Couldn't connect to database: " . DBI->errstr );

# get org unit name and shortnames
# sort so systems come above children
my $org_st = $dbh->prepare("select * from actor.org_unit where id != 1 order by parent_ou");

print("Initializing output file\n");
my $date_time =  DateTime->now;  
my $date_string = $date_time->strftime( '%Y%m%d' ); 
my $nice_date_string = $date_time->strftime( '%m.%d.%Y' ); 
my $output_filename = $date_string."_branches.html";
open(FH, '>', $output_filename) or die $!;
print FH "<html><body>";
# add style
print FH "<style>
        table.orgunits tr:nth-child(even) {
            background-color:#f7c1c1;
        }

         table.orgunits th {
            border-bottom: 2px solid #d14a0d;
            padding-bottom: 4px;        
        }
               
        table.orgunits th, table.orgunits td {
          text-align: left;
          padding: 16px;
        }
        
        table.orgunits{
      border-collapse: collapse;
      border-spacing: 0;
      width: 100%;
      border: 1px solid #ddd;
     }
     #title {
      color: #d14a0d;
      }
    #last-update {
        font-style: italic;
        color: #696969;
    }
        </style>";
# add header
print FH "<h1 id=\"title\"><strong>NC Cardinal Systems, Shipping Hubs, and Branches</strong></h1>
<h4 id=\"last-update\">Last updated $nice_date_string</h4>";

print FH "<table class=\"orgunits\">
    <thead>
        <tr>
            <th><h3>System</h3></th>
            <th><h3>Shipping Branch</h3></th>
            <th><h3>Other Branches</h3></th>
        </tr>
    </thead>
    <tbody>";
my %org_unit_data;
print("Retrieving org unit data\n");
my $current_org = 0;
$org_st->execute();
for((0..$org_st->rows-1)){
    my $sql_hash_ref = $org_st->fetchrow_hashref;
    
    $org_unit_data{ $sql_hash_ref->{'id'} } = { 
        id => $sql_hash_ref->{'id'}, 
        parent => $sql_hash_ref->{'parent_ou'},
        shortname => $sql_hash_ref->{'shortname'},
        name => $sql_hash_ref->{'name'}, 
        children => []
    };    
    unless($sql_hash_ref->{'parent_ou'} == 1){
        # add self to parent's children list, make processing easier later.
        my $parent_array_ref = $org_unit_data{$sql_hash_ref->{'parent_ou'}}->{'children'};        
        push @$parent_array_ref, $sql_hash_ref->{'id'};
    }
}


$org_st->finish();

# close connection to database       
$dbh->disconnect;
# create hash so we can get a good sort going
my %rows;
print("Building chart\n");
foreach my $system (keys %hubs)
{   
    my $row_data = "";
    my $sys_id = int(substr($system,8));

    my $sys_name = $org_unit_data{$sys_id}{name};
    my $sys_sname = $org_unit_data{$sys_id}{shortname};
    #open table row
    $row_data.= "<tr>";
    $row_data.= "<td><b>$sys_sname:</b> $sys_name</td>";
    #enter shipping hub info
    my $hub = $hubs{$system};
    my $hub_name = $org_unit_data{$hub}{name};
    my $hub_sname = $org_unit_data{$hub}{shortname};
    #enter system info
    $row_data.= "<td><b>$hub_sname:</b> $hub_name</td>";
    #open other systems td
    $row_data.= "<td><ul>";
    my $children_ref = $org_unit_data{$sys_id}{children};
    foreach my $child  (@$children_ref)
    {
        next if($hub == $org_unit_data{$child}{id});
        my $c_name = $org_unit_data{$child}{name};
        my $c_sname = $org_unit_data{$child}{shortname};
        $row_data.= "<li><b>$c_sname:</b> $c_name</li>";
    }    
    #close other systems td
    $row_data.= "</ul></td>";
    #close table row
    $row_data.= "</tr>";
    $rows{$sys_sname} = $row_data;
}

print("Sorting & exporting data\n");
foreach my $r (sort keys %rows) {
    print FH $rows{$r};
}

#close out HTML tags
print FH "</tbody>
</table>
</body>";


print("Closing files\n");
# close file
close(FH);
#log completion time   
my $complete_time = (time() - $total_time_start)/60.0;
print("script finished in $complete_time minutes\n");     
This PERL program connects to an Evergreen database to generate an HTML page of the consortium's systems, branches and shipping hubs. The shipping hub is the branch of the system which resource sharing materials are delievered to. 

## Dependencies

This program uses the following PERL dependencies:
* DBI
* Net::OpenSSH
* Config::Simple
* DateTime
* File::Spec
* File::Path
* File::Basename
* Data::Dumper

These should all be on CPAN.

## Installation

1. Set up your database connction in **sql_connection.ini** using the provided example file.
    * the first segment of that example file enables the use of an **SSH tunnel** and is optional.
    * the second segment is for the connection to your Evergreen database.
2. Set up your shipping hub connection in **shipping_hubs.ini** using the provided example file.
    *  this takes the form of SYSTEM_ID = SHIPPING_HUB_ID
3. Install the dependencies using CPAN.
    ```
    cpan -i DBI
    ```
## Usage

```
perl make_XML.pl
```

This will output a timestamped HTML file that can be put into your Knowledgebook.
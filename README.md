# sp_helpExpandView
https://sqlbek.wordpress.com/2015/03/03/debuting-sp_helpexpandview/

sp_helpExpandView will take a view & return a list of all objects referenced underneath. V1 supports references to child views, tables, inline functions, table valued functions, and 1 level of synonyms.

Output comes in two formats – vertical and horizontal.  Default is ‘all.’

Usage:
EXEC sp_helpExpandView
@ViewName = ‘[schema].[view]’,
@OutputFormat = ‘[all|vertical|horizontal]’

# Apartment Building Managerment System Project - Database Course 20221


## 1. Import database
* Backup roles  
```sh
psql -h localhost -U postgres -d dbname -f allroles.sql
```

* Backup data
```sh
psql -h localhost -U postgres -d dbname -f ABMSdatabase_dump.sql
```

## 2. Set up environment for GUI

- Go into “NewDatabaseProject20221” folder, open folder “gui” 

- Run cmd, input ‘python gui.py’, this will access users to a login window. Then users can enter their username and password to access the next window corresponding to role 

- Note: if the database name is not ‘Project’, please open source code of gui.py (by notepad or any IDE), then find the function:
```sh
def login_database(username_entry, password_entry): 
    username = username_entry.get() 
    password = password_entry.get() 
    try: 
        conn_t = psycopg2.connect( 
            host='localhost', 
            dbname='Project', 
            user=username, 
            password=password, 
            port='5432' 
        ) 
        cursor_t = conn_t.cursor() 
        login(username, password, conn_t, cursor_t) 
    except Exception as e: 
        messagebox.showerror("Error", "Invalid username or password, given: " + str(e)) 
```
And change the 'Project' to the name of your database

Login:

Admin account: 
+ username: admin1, password admin123

Service manager account: 
+ username: manager1, password: manager1123
+ username: manager2, password: manager2123
+ username: manager3, password: manager3123

Tenant account: username: 
+ tenant1, password: tenant1123

from pathlib import Path
from tkinter import Tk, Canvas, Entry, Button, PhotoImage, messagebox
import psycopg2
import tenantWindow
import serviceManagerWindow
import adminWindow


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


def login(username, password, conn_t, cursor_t):
    # Check if the user exists in the database
    cursor_t.execute(
        "SELECT json_agg(row_to_json(t)) FROM(SELECT * FROM get_role_and_account_id(%s, %s))t",
        (username, password)
    )
    result = cursor_t.fetchone()[0]
    print(result)
    if result:
        role_id = result[0]["_role_id"]
        print(role_id)
        # Close the login form
        window.destroy()
        # Open the main window based on the user's role
        if role_id == 1:
            connect_to_window(adminWindow, result, username, conn_t)
        elif role_id == 2:
            connect_to_window(serviceManagerWindow, result, username, conn_t)
        elif role_id == 3:
            connect_to_window(tenantWindow, result, username, conn_t)
        else:
            messagebox.showerror("Error", "Invalid role")
    else:
        messagebox.showerror("Error", "Invalid username or password")


def get_name(account_id, role_id, cursor_t):
    cursor_t.execute(
        "SELECT json_agg(row_to_json(t)) FROM(SELECT * FROM get_name(CAST(%s AS INT), CAST(%s AS INT)))t",
        (account_id, role_id)
    )
    result = cursor_t.fetchone()[0]
    first_name = result[0]['first_name']
    last_name = result[0]['last_name']
    return first_name + ' ' + last_name


def connect_to_window(connect_window, result, username, conn_t):
    connect_window.conn = conn_t
    connect_window.cursor = connect_window.conn.cursor()
    connect_window.username = username
    connect_window.account_id = result[0]["_account_id"]
    connect_window.role_id = result[0]["_role_id"]
    connect_window.name = get_name(connect_window.account_id, connect_window.role_id, connect_window.conn.cursor())
    connect_window.start()


OUTPUT_PATH = Path(__file__).parent
ASSETS_PATH = OUTPUT_PATH / Path(r"assets/frame0")


def relative_to_assets(path: str) -> Path:
    return ASSETS_PATH / Path(path)


window = Tk()

window.geometry("640x360")
window.configure(bg="#FFFFFF")

canvas = Canvas(
    window,
    bg="#FFFFFF",
    height=360,
    width=640,
    bd=0,
    highlightthickness=0,
    relief="ridge"
)

canvas.place(x=0, y=0)
image_image_1 = PhotoImage(
    file=relative_to_assets("image_1.png"))
image_1 = canvas.create_image(
    160.0,
    180.0,
    image=image_image_1
)

canvas.create_text(
    395.0,
    70.0,
    anchor="nw",
    text="LOGIN WINDOW",
    fill="#000000",
    font=("Inter SemiBold", 20 * -1)
)

image_image_2 = PhotoImage(
    file=relative_to_assets("image_2.png"))
image_2 = canvas.create_image(
    482.0,
    193.0,
    image=image_image_2
)

entry_image_1 = PhotoImage(
    file=relative_to_assets("entry_1.png"))
entry_bg_1 = canvas.create_image(
    482.0,
    196.5,
    image=entry_image_1
)
entry_1 = Entry(
    bd=0,
    bg="#E7E7E7",
    fg="#000716",
    highlightthickness=0
)
entry_1.place(
    x=382.0,
    y=189.0,
    width=200.0,
    height=13.0
)

image_image_3 = PhotoImage(
    file=relative_to_assets("image_3.png"))
image_3 = canvas.create_image(
    481.0,
    136.0,
    image=image_image_3
)

entry_image_2 = PhotoImage(
    file=relative_to_assets("entry_2.png"))
entry_bg_2 = canvas.create_image(
    480.5,
    140.5,
    image=entry_image_2
)
entry_2 = Entry(
    bd=0,
    bg="#E7E7E7",
    fg="#000716",
    highlightthickness=0
)
entry_2.place(
    x=380.0,
    y=133.0,
    width=201.0,
    height=13.0
)

button_image_1 = PhotoImage(
    file=relative_to_assets("button_1.png"))
button_1 = Button(
    image=button_image_1,
    borderwidth=0,
    highlightthickness=0,
    command=lambda: login_database(entry_2, entry_1),
    relief="flat"
)
button_1.place(
    x=407.0,
    y=233.0,
    width=150.0,
    height=26.0
)
window.resizable(False, False)
window.mainloop()

import tkinter as tk
from tkinter import ttk, messagebox
from db import get_connection


class EquestrianApp:
    def __init__(self, root):
        self.root = root
        self.root.title("CS351 – Equestrian Center Management System")
        self.root.geometry("900x600")

        self.tabs = ttk.Notebook(root)
        self.tabs.pack(fill="both", expand=True)

        self.create_owner_tab()
        self.create_horse_tab()
        self.create_lesson_tab()

    # ======================================================
    # OWNER TAB
    # ======================================================
    def create_owner_tab(self):
        tab = ttk.Frame(self.tabs)
        self.tabs.add(tab, text="Owners")

        ttk.Label(tab, text="Owner Name").grid(row=0, column=0, padx=5, pady=5)
        ttk.Label(tab, text="Phone").grid(row=1, column=0, padx=5, pady=5)
        ttk.Label(tab, text="Email").grid(row=2, column=0, padx=5, pady=5)

        self.owner_name = ttk.Entry(tab)
        self.owner_phone = ttk.Entry(tab)
        self.owner_email = ttk.Entry(tab)

        self.owner_name.grid(row=0, column=1)
        self.owner_phone.grid(row=1, column=1)
        self.owner_email.grid(row=2, column=1)

        ttk.Button(tab, text="Add Owner", command=self.add_owner).grid(row=3, column=1, pady=10)

        self.owner_table = ttk.Treeview(tab, columns=("ID", "Name", "Phone", "Email"), show="headings")
        for col in self.owner_table["columns"]:
            self.owner_table.heading(col, text=col)

        self.owner_table.grid(row=4, column=0, columnspan=3, sticky="nsew")
        self.load_owners()

    def add_owner(self):
        try:
            conn = get_connection()
            cur = conn.cursor()
            cur.execute(
                "INSERT INTO OWNER (Name, Phone, Email) VALUES (%s,%s,%s)",
                (self.owner_name.get(), self.owner_phone.get(), self.owner_email.get())
            )
            conn.commit()
            conn.close()
            self.load_owners()
            messagebox.showinfo("Success", "Owner added successfully")
        except Exception as e:
            messagebox.showerror("Error", str(e))

    def load_owners(self):
        for row in self.owner_table.get_children():
            self.owner_table.delete(row)

        conn = get_connection()
        cur = conn.cursor()
        cur.execute("SELECT OwnerID, Name, Phone, Email FROM OWNER")
        for row in cur.fetchall():
            self.owner_table.insert("", "end", values=row)
        conn.close()

    # ======================================================
    # HORSE TAB
    # ======================================================
    def create_horse_tab(self):
        tab = ttk.Frame(self.tabs)
        self.tabs.add(tab, text="Horses")

        labels = ["Name", "Type (School/Boarding)", "Gender", "DOB (YYYY-MM-DD)", "OwnerID", "StableID"]
        self.horse_entries = []

        for i, lbl in enumerate(labels):
            ttk.Label(tab, text=lbl).grid(row=i, column=0, padx=5, pady=5)
            entry = ttk.Entry(tab)
            entry.grid(row=i, column=1)
            self.horse_entries.append(entry)

        ttk.Button(tab, text="Add Horse", command=self.add_horse).grid(row=6, column=1, pady=10)

        self.horse_table = ttk.Treeview(
            tab,
            columns=("ID", "Name", "Type", "Gender", "DOB", "OwnerID", "StableID"),
            show="headings"
        )

        for col in self.horse_table["columns"]:
            self.horse_table.heading(col, text=col)

        self.horse_table.grid(row=7, column=0, columnspan=4, sticky="nsew")
        self.load_horses()

    def add_horse(self):
        try:
            data = [e.get() if e.get() != "" else None for e in self.horse_entries]
            conn = get_connection()
            cur = conn.cursor()
            cur.execute("""
                INSERT INTO HORSE (Name, Type, Gender, DateOfBirth, OwnerID, StableID)
                VALUES (%s,%s,%s,%s,%s,%s)
            """, data)
            conn.commit()
            conn.close()
            self.load_horses()
            messagebox.showinfo("Success", "Horse added successfully")
        except Exception as e:
            messagebox.showerror("Error", str(e))

    def load_horses(self):
        for row in self.horse_table.get_children():
            self.horse_table.delete(row)

        conn = get_connection()
        cur = conn.cursor()
        cur.execute("""
            SELECT HorseID, Name, Type, Gender, DateOfBirth, OwnerID, StableID
            FROM HORSE
        """)
        for row in cur.fetchall():
            self.horse_table.insert("", "end", values=row)
        conn.close()

    # ======================================================
    # LESSON TAB
    # ======================================================
    def create_lesson_tab(self):
        tab = ttk.Frame(self.tabs)
        self.tabs.add(tab, text="Lessons")

        self.lesson_table = ttk.Treeview(
            tab,
            columns=("ID", "Date", "Start", "End", "Type", "Arena", "Trainer"),
            show="headings"
        )

        for col in self.lesson_table["columns"]:
            self.lesson_table.heading(col, text=col)

        self.lesson_table.pack(fill="both", expand=True)
        self.load_lessons()

    def load_lessons(self):
        for row in self.lesson_table.get_children():
            self.lesson_table.delete(row)

        conn = get_connection()
        cur = conn.cursor()
        cur.execute("""
            SELECT LessonID, LessonDate, StartTime, EndTime, Type, ArenaID, TrainerID
            FROM LESSON
            ORDER BY LessonDate, StartTime
        """)
        for row in cur.fetchall():
            self.lesson_table.insert("", "end", values=row)
        conn.close()


# ======================================================
# RUN APP
# ======================================================
if __name__ == "__main__":
    root = tk.Tk()
    app = EquestrianApp(root)
    root.mainloop()

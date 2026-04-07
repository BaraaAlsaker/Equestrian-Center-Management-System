import mysql.connector   # ✅ ADD THIS LINE

def get_connection():
    return mysql.connector.connect(
        host="localhost",
        user="YOUR_USERNAME",
        password="YOUR_PASSWORD",
        database="CS351_EquestrianCenter1"
    )

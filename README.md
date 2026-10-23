# JAVA_Project

# Laboratory Equipment Lifecycle & Maintenance System (LELMS)

## Overview

The **Laboratory Equipment Lifecycle & Maintenance System (LELMS)** is a Java-based desktop application developed to manage laboratory equipment and maintain its inventory records. The application uses Java Swing to provide a graphical user interface, JDBC to connect to the database, and MySQL to store and retrieve equipment information.

The system supports equipment inventory management, status tracking, database CRUD operations, and stored procedure integration.

## Features

- **Create Equipment:** Insert new equipment records into the database.
- **View Equipment:** Retrieve and display equipment inventory in a table.
- **Update Equipment:** Modify existing equipment information.
- **Delete Equipment:** Remove equipment records from the database.
- **Equipment Status Tracking:** Track statuses such as `AVAILABLE`, `UNDER_MAINTENANCE`, `CALIBRATION_DUE`, and `DECOMMISSIONED`.
- **Stored Procedure Integration:** Call a MySQL stored procedure to issue a selected equipment unit.
- **Health Monitoring:** Display equipment health classifications based on available equipment data.
- **Live Status Summary:** Display equipment counts by status using background monitoring.

## Technologies Used

| Technology | Purpose |
|---|---|
| Java | Application logic |
| Java Swing | Graphical user interface |
| JDBC | Connectivity between Java and MySQL |
| MySQL | Database management |
| MySQL Connector/J | JDBC driver for MySQL |
| SQL | Database queries and CRUD operations |
| Stored Procedures | Encapsulate database operations |

## Project Structure

```text
JAVA_Project_JDBC/
├── .vscode/
├── bin/                              # Compiled Java classes
├── lib/
│   └── mysql-connector-j-26.7.0.jar  # MySQL JDBC driver
├── src/
│   └── LelmsFullProject.java         # Main application source
└── README.md
```

## Prerequisites

Before running the application, ensure that you have:

- Java Development Kit (JDK) installed.
- MySQL Server installed and running.
- A MySQL database containing the required equipment tables and stored procedure.
- MySQL Connector/J JAR file in the `lib` directory.
- Visual Studio Code or another Java-compatible IDE.

## Database Configuration

1. Start your MySQL Server.
2. Create or select the database used by the application.
3. Ensure that the required tables and stored procedure exist.
4. Configure the JDBC connection URL, username, and password in the Java source code.

A typical JDBC URL follows this format:

```java
jdbc:mysql://localhost:3306/your_database
```

Replace `your_database` with the actual database name.

**Security note:** Do not commit database passwords or other credentials to a public repository. Use environment variables or a separate configuration file excluded from version control.

## How to Run

Open the project folder in VS Code and open a terminal in the directory containing `src`, `bin`, and `lib`.

### Step 1: Compile the Java source

```powershell
javac -cp "lib\mysql-connector-j-26.7.0.jar" -d bin src\LelmsFullProject.java
```

### Step 2: Run the application

```powershell
java -cp "bin;lib\mysql-connector-j-26.7.0.jar" LelmsFullProject
```

These commands assume that the Java class is in the default package and that the JAR filename matches the file in your `lib` directory.

## Application Workflow

1. Launch the Java Swing application.
2. View the equipment records displayed in the inventory table.
3. Select a row to populate the input fields, where supported.
4. Use the Create, Refresh, Update, and Delete buttons to perform database operations.
5. Use the Issue Selected Unit button to invoke the stored procedure.
6. Monitor equipment status and the live status summary.

## Error Handling

The application may report database connection or query errors if:

- MySQL Server is not running.
- The JDBC URL or database name is incorrect.
- The database username or password is invalid.
- Required tables or stored procedures are missing.
- The JDBC driver is unavailable on the classpath.

Verify the database configuration and server status if the inventory cannot be loaded.

## Future Enhancements

- Add user authentication and role-based access.
- Implement maintenance scheduling and reminders.
- Generate equipment utilization and maintenance reports.
- Add audit logs for equipment updates.
- Improve input validation and error reporting.
- Support configurable database connection settings.

## Conclusion

LELMS demonstrates the integration of Java Swing, JDBC, and MySQL in a desktop-based equipment management application. It provides a graphical interface for inventory operations, equipment status tracking, and stored procedure execution, while illustrating practical database connectivity and Java application development.

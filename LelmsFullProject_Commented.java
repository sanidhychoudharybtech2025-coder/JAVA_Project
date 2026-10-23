// Imports Swing classes used to build the desktop GUI.
import javax.swing.*;
// Imports the table model that stores rows shown in JTable.
import javax.swing.table.DefaultTableModel; 
//Abstract Window Toolkit.It is a part of Java used to create 
// graphical user interfaces (GUI), such as windows, buttons, text fields, labels, and layouts.
// Imports AWT layout managers and GUI-related utilities.
import java.awt.*;
// BigDecimal stores decimal values accurately, especially costs.
import java.math.BigDecimal;
// Imports JDBC classes used to connect to MySQL and run SQL.
import java.sql.*;
// LocalDate represents a calendar date without a time.
import java.time.LocalDate;
// Imports utility collections such as ArrayList, Map and LinkedHashMap.
import java.util.*;
// Explicit List import resolves the List name alongside wildcard imports.
import java.util.List;

// ============================================================================
// 1. EXCEPTION HANDLING (1 MARK): Custom Domain Exception
// ============================================================================
// A custom checked exception for errors in this equipment-management project.
class EquipmentLifecycleException extends Exception {
    // Stores the SQL state code associated with the database error.
    private final String sqlState;
    // Constructor receives a readable message, SQL state, and original cause.
    public EquipmentLifecycleException(String message, String sqlState, Throwable cause) { //constructor
        // Pass message and cause to Exception so the original error is retained.
        super(message, cause);
        // Save the SQL state for later inspection.
        this.sqlState = sqlState;
    }
    // Returns the saved SQL state.
    public String getSqlState() { return sqlState; }
}

// ============================================================================
// 2. INHERITANCE (1 MARK): Superclass & Subclass Hierarchy
// ============================================================================
// Parent class: common information shared by all equipment assets.
class EquipmentAsset {
    // protected allows this class, subclasses, and same-package code to access the field.
    protected int unitId;
    // Unique human-readable equipment tag.
    protected String assetTag;
    // Manufacturer or equipment serial number.
    protected String serialNumber;
    // Equipment model name.
    protected String modelName;
    // Code identifying the laboratory.
    protected String labCode;
    // Current equipment status.
    protected String status;
    // Purchase/acquisition cost, represented as a precise decimal.
    protected BigDecimal acquisitionCost;
    // Total usage hours, represented as a precise decimal.
    protected BigDecimal cumulativeHours;

    // Constructor initializes the common equipment fields.
    public EquipmentAsset(int unitId, String assetTag, String serialNumber,
                          String modelName, String labCode, String status,
                          BigDecimal acquisitionCost, BigDecimal cumulativeHours) {
        // this.unitId means the field of this object; unitId is the parameter.
        this.unitId = unitId;
        // Copy the supplied asset tag into this object.
        this.assetTag = assetTag;
        // Copy the supplied serial number into this object.
        this.serialNumber = serialNumber;
        // Copy the supplied model name into this object.
        this.modelName = modelName;
        // Copy the supplied lab code into this object.
        this.labCode = labCode;
        // Copy the supplied status into this object.
        this.status = status;
        // Copy the acquisition cost into this object.
        this.acquisitionCost = acquisitionCost;
        // Copy cumulative usage hours into this object.
        this.cumulativeHours = cumulativeHours;
    }

    // Produces an array containing values in the order expected by the GUI table.
    public Object[] toTableRow() {
        // Return one Object array; Object can hold values of different types.
        return new Object[]{unitId, assetTag, serialNumber, modelName, labCode, status, acquisitionCost, cumulativeHours, "Standard"};
    }
}

// Child class inherits common fields and behavior from EquipmentAsset.
class MonitoredEquipmentAsset extends EquipmentAsset {
    // Extra financial value for monitored equipment; final prevents reassignment.
    private final BigDecimal currentBookValue;
    // Total maintenance spending for this equipment.
    private final BigDecimal maintenanceSpend;

    // Constructor receives the common fields plus two monitoring fields.
    public MonitoredEquipmentAsset(int unitId, String assetTag, String serialNumber,
                                   String modelName, String labCode, String status,
                                   BigDecimal acquisitionCost, BigDecimal cumulativeHours,
                                   BigDecimal currentBookValue, BigDecimal maintenanceSpend) {
        // Call the parent constructor to initialize inherited fields first.
        super(unitId, assetTag, serialNumber, modelName, labCode, status, acquisitionCost, cumulativeHours);
        // Store the current book value.
        this.currentBookValue = currentBookValue;
        // Store the maintenance expenditure.
        this.maintenanceSpend = maintenanceSpend;
    }

    // Override the parent's table-row method to display monitored values.
    @Override
    public Object[] toTableRow() {
        // Return values matching the table's nine columns.
        return new Object[]{
            unitId, assetTag, serialNumber, modelName, labCode,
            status, currentBookValue, cumulativeHours, "Maint: " + maintenanceSpend
        };
    }
}

// DAO means Data Access Object: this class contains database operations.
// ============================================================================
// It also demonstrates CRUD operations and Java collections.
// 3. JDBC CRUD DAO (2 MARKS) + COLLECTIONS (1 MARK)
// ============================================================================
// The DAO handles the connection and SQL operations for equipment data.
class EquipmentLifecycleDAO {
    // JDBC connection URL.
    private final String url;
    // MySQL username.
    private final String user;
    // MySQL password.
    private final String password;

    // Constructor accepts connection details as parameters.
    public EquipmentLifecycleDAO(String url, String user, String password) {
        // NOTE: the supplied URL parameter is ignored; this field is hard-coded.
        this.url = "jdbc:mysql://localhost:3306/lab_equipment_lms";
        // NOTE: the supplied username parameter is ignored; this is hard-coded.
        this.user = "root";
        // NOTE: the supplied password parameter is ignored; this is hard-coded.
        this.password = "sanidhy";
    }

    // Opens a connection to the configured database; SQL errors can be thrown.
    private Connection getConnection() throws SQLException {
        // DriverManager creates the connection using the saved URL and credentials.
        return DriverManager.getConnection(url, user, password);
    }

    // READ operation: retrieve all equipment rows into a List.
    // READ (R of CRUD): Fetch all equipment units into a List<EquipmentAsset>
    // The method may throw the project's custom exception if the query fails.
    public List<EquipmentAsset> readAllUnits() throws EquipmentLifecycleException {
        // Start with an empty ArrayList to collect equipment objects.
        List<EquipmentAsset> units = new ArrayList<>();
        // First part of the SELECT query: choose equipment columns.
        String sql = "SELECT unit_id, asset_tag, serial_number, model_name, lab_code, status, " +
                     "acquisition_cost, cumulative_usage_hours, current_book_value, total_maintenance_spend " +
                     "FROM vw_equipment_lifecycle_summary ORDER BY unit_id";
        // try-with-resources automatically closes these database resources.
        try (Connection conn = getConnection();
             // Prepare the SQL statement on this database connection.
             PreparedStatement ps = conn.prepareStatement(sql);
             // Execute the SELECT and hold the returned rows in ResultSet.
             ResultSet rs = ps.executeQuery()) {
            // Move through the result one row at a time.
            while (rs.next()) {
                // Build a child-class object from the current database row and add it to the list.
                units.add(new MonitoredEquipmentAsset(
                    // Read the unit ID column as an integer.
                    rs.getInt("unit_id"),
                    // Read the asset tag as text.
                    rs.getString("asset_tag"),
                    // Read the serial number as text.
                    rs.getString("serial_number"),
                    // Read the model name as text.
                    rs.getString("model_name"),
                    // Read the laboratory code as text.
                    rs.getString("lab_code"),
                    // Read the status as text.
                    rs.getString("status"),
                    // Read acquisition cost as BigDecimal.
                    rs.getBigDecimal("acquisition_cost"),
                    // Read cumulative usage hours as BigDecimal.
                    rs.getBigDecimal("cumulative_usage_hours"),
                    // Read current book value as BigDecimal.
                    rs.getBigDecimal("current_book_value"),
                    // Read total maintenance spending as BigDecimal.
                    rs.getBigDecimal("total_maintenance_spend")
                ));
            }
            // Return the complete list of equipment objects.
            return units;
        // Catch database-related errors from the SQL operation.
        } catch (SQLException e) {
            // Wrap the SQL error in the project's custom exception.
            throw new EquipmentLifecycleException("Failed to read equipment inventory: " + e.getMessage(), e.getSQLState(), e);
        }
    }

    // COLLECTIONS example: count equipment units grouped by status.
    // COLLECTIONS: Aggregate unit counts by status using Map<String, Integer>
    // Returns a Map where each status string maps to an integer count.
    public Map<String, Integer> getStatusDistribution() throws EquipmentLifecycleException {
        // LinkedHashMap stores key/value pairs and preserves insertion order.
        Map<String, Integer> statusMap = new LinkedHashMap<>();
        // SQL counts rows in each status group.
        String sql = "SELECT status, COUNT(*) AS cnt FROM equipment_unit GROUP BY status";
        // Open connection, prepare query, and execute it with auto-closing resources.
        try (Connection conn = getConnection();
             PreparedStatement ps = conn.prepareStatement(sql);
             ResultSet rs = ps.executeQuery()) {
            // Process each status/count row returned by MySQL.
            while (rs.next()) {
                // Store status as the key and its count as the value.
                statusMap.put(rs.getString("status"), rs.getInt("cnt"));
            }
            // Return the status-to-count mapping.
            return statusMap;
        // Convert an SQL failure to the custom exception.
        } catch (SQLException e) {
            // Preserve the error message, SQL state and original exception.
            throw new EquipmentLifecycleException("Failed to compute status distribution: " + e.getMessage(), e.getSQLState(), e);
        }
    }

    // CREATE operation: insert a new equipment unit.
    // CREATE (C of CRUD): Insert a new equipment_unit row
    // Parameters supply its tag, serial number, model ID, lab ID and cost.
    public int createEquipmentUnit(String assetTag, String serialNo, int modelId, int labId, BigDecimal cost)
            throws EquipmentLifecycleException {
        // INSERT adds a row; question marks are placeholders for safe parameter binding.
        String sql = "INSERT INTO equipment_unit (asset_tag, serial_number, model_id, current_lab_id, " +
                     "acquisition_date, acquisition_cost, salvage_estimate, status) VALUES (?, ?, ?, ?, ?, ?, ?, 'AVAILABLE')";
        // Open a connection and prepare the INSERT statement.
        try (Connection conn = getConnection();
             // Request the database-generated primary key after insertion.
             PreparedStatement ps = conn.prepareStatement(sql, Statement.RETURN_GENERATED_KEYS)) {
            // Bind parameter 1 to the asset tag.
            ps.setString(1, assetTag);
            // Bind parameter 2 to the serial number.
            ps.setString(2, serialNo);
            // Bind parameter 3 to the model ID.
            ps.setInt(3, modelId);
            // Bind parameter 4 to the laboratory ID.
            ps.setInt(4, labId);
            // Bind parameter 5 to today's date.
            ps.setDate(5, java.sql.Date.valueOf(LocalDate.now()));
            // Bind parameter 6 to acquisition cost.
            ps.setBigDecimal(6, cost);
            // Estimate salvage value as 10% of the acquisition cost.
            ps.setBigDecimal(7, cost.multiply(new BigDecimal("0.10")));
            // Execute the INSERT; return value is the number of affected rows.
            ps.executeUpdate();
            // Read the generated key returned by MySQL.
            try (ResultSet keys = ps.getGeneratedKeys()) {
                // Return the generated ID, or -1 if no key was returned.
                return keys.next() ? keys.getInt(1) : -1;
            }
        // Catch database errors during insertion.
        } catch (SQLException e) {
            // Wrap the SQL error with a message identifying the CREATE operation.
            throw new EquipmentLifecycleException("Create Equipment Failed: " + e.getMessage(), e.getSQLState(), e);
        }
    }

    // UPDATE operation: change status and add to cumulative usage hours.
    // UPDATE (U of CRUD): Update equipment status and usage hours (fires audit_log trigger)
    // unitId selects the row; newStatus and addHours are the new values.
    public int updateEquipmentStatusAndHours(int unitId, String newStatus, BigDecimal addHours)
            throws EquipmentLifecycleException {
        // Update one row by ID; addHours is added to the existing hours.
        String sql = "UPDATE equipment_unit SET status = ?, cumulative_usage_hours = cumulative_usage_hours + ? WHERE unit_id = ?";
        // Prepare the parameterized UPDATE statement.
        try (Connection conn = getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            // Bind the new status.
            ps.setString(1, newStatus);
            // Bind the number of hours to add.
            ps.setBigDecimal(2, addHours);
            // Bind the unit ID used by WHERE to select the row.
            ps.setInt(3, unitId);
            // Execute the UPDATE and return the number of affected rows.
            return ps.executeUpdate();
        // Catch database errors during update.
        } catch (SQLException e) {
            // Wrap the error as an equipment-update failure.
            throw new EquipmentLifecycleException("Update Equipment Failed: " + e.getMessage(), e.getSQLState(), e);
        }
    }

    // DELETE operation: remove a unit by its ID.
    // DELETE (D of CRUD): Delete a decommissioned/unused equipment unit by ID
    // Returns the number of database rows deleted.
    public int deleteEquipmentUnit(int unitId) throws EquipmentLifecycleException {
        // DELETE removes the row matching this unit ID.
        String sql = "DELETE FROM equipment_unit WHERE unit_id = ?";
        // Prepare the DELETE statement using a database connection.
        try (Connection conn = getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            // Bind the unit ID to the placeholder.
            ps.setInt(1, unitId);
            // Execute deletion and return the number of rows affected.
            return ps.executeUpdate();
        // Catch errors, including possible foreign-key constraint failures.
        } catch (SQLException e) {
            // Explain that related rows or constraints may prevent deletion.
            throw new EquipmentLifecycleException("Delete Equipment Failed (Check FK constraints): " + e.getMessage(), e.getSQLState(), e);
        }
    }

    // Calls a MySQL stored procedure to issue equipment to a borrower.
    // STORED PROCEDURE CALL: Issue Equipment
    // Inputs identify the equipment, borrower, issuer, due date and purpose.
    public void issueEquipment(int unitId, int borrowerId, int issuerId, String expectedReturnDate, String purpose)
            throws EquipmentLifecycleException {
        // JDBC call syntax for a stored procedure with five parameters.
        String call = "{CALL sp_issue_equipment(?, ?, ?, ?, ?)}";
        // Open a connection and prepare the stored-procedure call.
        try (Connection conn = getConnection();
             // CallableStatement is used to invoke stored procedures.
             CallableStatement cs = conn.prepareCall(call)) {
            // Bind the equipment unit ID.
            cs.setInt(1, unitId);
            // Bind the borrower ID.
            cs.setInt(2, borrowerId);
            // Bind the staff member issuing the equipment.
            cs.setInt(3, issuerId);
            // Convert the expected return date string to a SQL Date.
            cs.setDate(4, java.sql.Date.valueOf(expectedReturnDate));
            // Bind the purpose of the issue.
            cs.setString(5, purpose);
            // Execute the stored procedure in MySQL.
            cs.execute();
        // Catch errors from the stored procedure call.
        } catch (SQLException e) {
            // Wrap the error with the procedure name for easier diagnosis.
            throw new EquipmentLifecycleException("Procedure sp_issue_equipment failed: " + e.getMessage(), e.getSQLState(), e);
        }
    }
}

// ============================================================================
// 4. GUI (1 MARK) + MULTITHREADED MONITOR (1 MARK)
// ============================================================================
// Main GUI class: extends JFrame, so this class is a desktop window.
public class LelmsFullProject extends JFrame {
    // Create the DAO used by the GUI to perform database operations.
    private final EquipmentLifecycleDAO dao = new EquipmentLifecycleDAO(
        "jdbc:mysql://localhost:3306/lab_equipment_lms", "root", "sanidhy"
    );

    // Table model defines column headings and stores displayed rows.
    private final DefaultTableModel tableModel = new DefaultTableModel(
        // The nine column names are used when displaying each asset row.
        new String[]{"Unit ID", "Asset Tag", "Serial No", "Model", "Lab", "Status", "Book Value", "Hours", "Maint Spend"}, 0
    );
    // Label at the bottom displays background-monitor status or errors.
    private final JLabel lblMonitorStatus = new JLabel("Initializing background telemetry thread...");

    // Text field for the unit ID used by update/delete.
    private final JTextField tfUnitId = new JTextField(4);
    // Text field for the asset tag during creation.
    private final JTextField tfAssetTag = new JTextField(10);
    // Text field for the serial number during creation.
    private final JTextField tfSerial = new JTextField(10);
    // Text field for model ID; initially contains 1.
    private final JTextField tfModelId = new JTextField("1", 3);
    // Text field for lab ID; initially contains 1.
    private final JTextField tfLabId = new JTextField("1", 3);
    // Text field for cost; initially contains 150000.
    private final JTextField tfCost = new JTextField("150000", 7);
    // Dropdown lets the user choose an equipment status.
    private final JComboBox<String> cbStatus = new JComboBox<>(new String[]{
        "AVAILABLE", "IN_USE", "UNDER_MAINTENANCE", "CALIBRATION_DUE", "DECOMMISSIONED"
    });
    // Text field for the number of usage hours to add during update.
    private final JTextField tfAddHours = new JTextField("5.0", 4);

    // Constructor builds and initializes the application window.
    public LelmsFullProject() {
        // Set the title displayed in the window's title bar.
        super("Laboratory Equipment Lifecycle & Maintenance System (JDBC + Swing)");
        // Set the window dimensions in pixels.
        setSize(1080, 560);
        // Close the application when the user closes the window.
        setDefaultCloseOperation(EXIT_ON_CLOSE);
        // Use BorderLayout to arrange components in five regions.
        setLayout(new BorderLayout(8, 8));

        // Center Table
        // Create a table linked to the table model.
        JTable table = new JTable(tableModel);
        // Put the table in a scroll pane and place it in the center.
        add(new JScrollPane(table), BorderLayout.CENTER);

        // North CRUD Form Panel
        // Arrange form controls in a left-to-right flow layout.
        JPanel crudPanel = new JPanel(new FlowLayout(FlowLayout.LEFT, 6, 6));
        // Add a titled border around the CRUD form.
        crudPanel.setBorder(BorderFactory.createTitledBorder("JDBC CRUD Operations"));
        // Add an ID label and its text field to the form.
        crudPanel.add(new JLabel("ID:")); crudPanel.add(tfUnitId);
        // Add the asset-tag label and field.
        crudPanel.add(new JLabel("Tag:")); crudPanel.add(tfAssetTag);
        // Add the serial-number label and field.
        crudPanel.add(new JLabel("S/N:")); crudPanel.add(tfSerial);
        // Add the model-ID label and field.
        crudPanel.add(new JLabel("ModelID:")); crudPanel.add(tfModelId);
        // Add the lab-ID label and field.
        crudPanel.add(new JLabel("LabID:")); crudPanel.add(tfLabId);
        // Add the cost label and field.
        crudPanel.add(new JLabel("Cost:")); crudPanel.add(tfCost);
        // Add the status label and dropdown.
        crudPanel.add(new JLabel("Status:")); crudPanel.add(cbStatus);
        // Add the usage-hours label and field.
        crudPanel.add(new JLabel("+Hrs:")); crudPanel.add(tfAddHours);

        // Button to create a database row.
        JButton btnCreate = new JButton("Create (INSERT)");
        // Button to reload the displayed table.
        JButton btnRead   = new JButton("Read (SELECT)");
        // Button to update a database row.
        JButton btnUpdate = new JButton("Update (UPDATE)");
        // Button to delete a database row.
        JButton btnDelete = new JButton("Delete (DELETE)");

        // When clicked, call the method that handles creation.
        btnCreate.addActionListener(e -> handleCreate());
        // When clicked, refresh the table in a background thread.
        btnRead.addActionListener(e -> refreshTableAsync());
        // When clicked, call the update handler.
        btnUpdate.addActionListener(e -> handleUpdate());
        // When clicked, call the delete handler.
        btnDelete.addActionListener(e -> handleDelete());

        // Add the Create button to the form.
        crudPanel.add(btnCreate);
        // Add the Refresh button to the form.
        crudPanel.add(btnRead);
        // Add the Update button to the form.
        crudPanel.add(btnUpdate);
        // Add the Delete button to the form.
        crudPanel.add(btnDelete);
        // Place the CRUD form at the top of the window.
        add(crudPanel, BorderLayout.NORTH);

        // South Status Bar updated by Daemon Thread
        // Create the bottom status panel using BorderLayout.
        JPanel southPanel = new JPanel(new BorderLayout());
        // Add empty padding around the status panel.
        southPanel.setBorder(BorderFactory.createEmptyBorder(4, 8, 4, 8));
        // Put the status label in the center of the bottom panel.
        southPanel.add(lblMonitorStatus, BorderLayout.CENTER);
        // Place the status panel at the bottom of the window.
        add(southPanel, BorderLayout.SOUTH);

        // Load the initial equipment table asynchronously.
        refreshTableAsync();
        // Start the repeating background status-monitor thread.
        startBackgroundHealthThread();
    }

    // Handles the Create button.
    private void handleCreate() {
        // Try the operation; malformed input or database errors are caught below.
        try {
            // Call DAO method and save the ID returned by the database.
            int newId = dao.createEquipmentUnit(
                // Read and trim the asset tag field.
                tfAssetTag.getText().trim(),
                // Read and trim the serial-number field.
                tfSerial.getText().trim(),
                // Convert model ID text into an integer.
                Integer.parseInt(tfModelId.getText().trim()),
                // Convert lab ID text into an integer.
                Integer.parseInt(tfLabId.getText().trim()),
                // Convert cost text into BigDecimal.
                new BigDecimal(tfCost.getText().trim())
            );
            // Show a dialog with the generated equipment ID.
            JOptionPane.showMessageDialog(this, "Created Equipment Unit ID: " + newId);
            // Reload the table so the new row appears.
            refreshTableAsync();
        // Catch input errors and other exceptions.
        } catch (Exception ex) {
            // Show the error message in a dialog.
            JOptionPane.showMessageDialog(this, ex.getMessage(), "Create Error", JOptionPane.ERROR_MESSAGE);
        }
    }

    // Handles the Update button.
    private void handleUpdate() {
        // Begin protected operation; invalid numeric text can cause an exception.
        try {
            // Call DAO method that updates status and adds usage hours.
            int rows = dao.updateEquipmentStatusAndHours(
                // Convert the unit ID field to an integer.
                Integer.parseInt(tfUnitId.getText().trim()),
                // Read the currently selected status from the dropdown.
                (String) cbStatus.getSelectedItem(),
                // Convert added hours to BigDecimal.
                new BigDecimal(tfAddHours.getText().trim())
            );
            // Tell the user how many rows were updated.
            JOptionPane.showMessageDialog(this, "Updated rows: " + rows + " (audit_log trigger fired)");
            // Refresh the visible table after the update.
            refreshTableAsync();
        // Catch errors from input parsing or the database.
        } catch (Exception ex) {
            // Display the update error.
            JOptionPane.showMessageDialog(this, ex.getMessage(), "Update Error", JOptionPane.ERROR_MESSAGE);
        }
    }

    // Handles the Delete button.
    private void handleDelete() {
        // Begin the operation that may fail.
        try {
            // Convert ID text to integer and ask the DAO to delete that unit.
            int rows = dao.deleteEquipmentUnit(Integer.parseInt(tfUnitId.getText().trim()));
            // Show how many rows were deleted.
            JOptionPane.showMessageDialog(this, "Deleted rows: " + rows);
            // Reload the table after deletion.
            refreshTableAsync();
        // Catch invalid input or database errors.
        } catch (Exception ex) {
            // Display the delete error.
            JOptionPane.showMessageDialog(this, ex.getMessage(), "Delete Error", JOptionPane.ERROR_MESSAGE);
        }
    }

    // Loads database rows without blocking the GUI thread.
    private void refreshTableAsync() {
        // Start a new worker thread using a lambda expression.
        new Thread(() -> {
            try {
                // Read all equipment records into a List.
                List<EquipmentAsset> list = dao.readAllUnits();
                // Schedule GUI changes on Swing's Event Dispatch Thread.
                SwingUtilities.invokeLater(() -> {
                    // Remove existing displayed rows to avoid duplicates.
                    tableModel.setRowCount(0);
                    // Visit each retrieved equipment object.
                    for (EquipmentAsset asset : list) {
                        // Convert the object to a row array and add it to the table.
                        tableModel.addRow(asset.toTableRow());
                    }
                });
            // Handle custom database exceptions.
            } catch (EquipmentLifecycleException ex) {
                // Schedule status-label changes on the GUI thread.
                SwingUtilities.invokeLater(() ->
                    // Display a database connection/query error.
                    lblMonitorStatus.setText("DB Connection Error: " + ex.getMessage())
                );
            }
        // Start the worker thread.
        }).start();
    }

    // Starts a daemon thread that periodically checks equipment status counts.
    // 6. THREAD (1 MARK): Daemon monitoring thread polling status distribution
    // This method sets up and starts the monitoring thread.
    private void startBackgroundHealthThread() {
        // Define the work the monitor thread will perform.
        Thread monitorThread = new Thread(() -> {
            // Keep monitoring until the thread is interrupted.
            while (!Thread.currentThread().isInterrupted()) {
                // Begin one monitoring cycle.
                try {
                    // Query the database for counts grouped by status.
                    Map<String, Integer> dist = dao.getStatusDistribution();
                    // Update Swing UI components on the Event Dispatch Thread.
                    SwingUtilities.invokeLater(() ->
                        // Show the latest status-to-count map in the label.
                        lblMonitorStatus.setText("Live Status Summary (Background Thread): " + dist.toString())
                    );
                    // Pause for 15 seconds before the next poll.
                    Thread.sleep(15000);
                // Handle interruption while sleeping.
                } catch (InterruptedException ie) {
                    // Restore the interrupted status so the loop can stop.
                    Thread.currentThread().interrupt();
                // Handle other monitoring/database errors.
                } catch (Exception ex) {
                    // Schedule the warning message on the GUI thread.
                    SwingUtilities.invokeLater(() ->
                        // Show the monitoring error in the status label.
                        lblMonitorStatus.setText("Telemetry Warning: " + ex.getMessage())
                    );
                    // Wait before retrying; stop if this sleep is interrupted.
                    try { Thread.sleep(15000); } catch (InterruptedException ie) { break; }
                }
            }
        // Give the thread a descriptive name for debugging.
        }, "LELMS-Health-Monitor-Thread");
        // Daemon threads do not keep the application alive by themselves.
        monitorThread.setDaemon(true);
        // Start executing the monitor thread.
        monitorThread.start();
    }

    // Java application entry point.
    public static void main(String[] args) {
        // Create and show the window on Swing's Event Dispatch Thread.
        SwingUtilities.invokeLater(() -> new LelmsFullProject().setVisible(true));
    }
}

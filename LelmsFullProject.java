import javax.swing.*;
import javax.swing.table.DefaultTableModel;
import java.awt.*;
import java.math.BigDecimal;
import java.sql.*;
import java.time.LocalDate;
import java.util.*;
import java.util.List;
import java.util.regex.Pattern;

// ============================================================================
// 1. EXCEPTION HANDLING (1 MARK)
// ============================================================================
class EquipmentLifecycleException extends Exception {
    private final String sqlState;
    private final int vendorErrorCode;

    public EquipmentLifecycleException(String message, SQLException cause) {
        super(message, cause);
        this.sqlState = cause != null ? cause.getSQLState() : "N/A";
        this.vendorErrorCode = cause != null ? cause.getErrorCode() : -1;
    }

    public String getDiagnosticSummary() {
        return String.format("%s [SQLState: %s | ErrorCode: %d]", getMessage(), sqlState, vendorErrorCode);
    }
}

class InvalidEquipmentInputException extends RuntimeException {
    public InvalidEquipmentInputException(String message) {
        super(message);
    }
}

// ============================================================================
// 2. INHERITANCE (1 MARK)
// ============================================================================
abstract class LifecycleEntity {
    protected int unitId;
    protected LifecycleEntity(int unitId) {
        this.unitId = unitId;
    }
    public int getUnitId() { return unitId; }
    public abstract String computeHealthBadge();
    public abstract Object[] toTableRow();
}

class EquipmentAsset extends LifecycleEntity {
    protected String assetTag;
    protected String serialNumber;
    protected String modelName;
    protected String labCode;
    protected String status;
    protected BigDecimal acquisitionCost;
    protected BigDecimal cumulativeHours;

    public EquipmentAsset(int unitId, String assetTag, String serialNumber,
                          String modelName, String labCode, String status,
                          BigDecimal acquisitionCost, BigDecimal cumulativeHours) {
        super(unitId);
        this.assetTag = assetTag;
        this.serialNumber = serialNumber;
        this.modelName = modelName;
        this.labCode = labCode;
        this.status = status;
        this.acquisitionCost = acquisitionCost;
        this.cumulativeHours = cumulativeHours;
    }

    @Override
    public String computeHealthBadge() {
        return cumulativeHours.compareTo(new BigDecimal("1000")) >= 0 ? "HIGH_WEAR" : "NORMAL";
    }

    @Override
    public Object[] toTableRow() {
        return new Object[]{
            unitId, assetTag, serialNumber, modelName, labCode,
            status, acquisitionCost, cumulativeHours, "0.00", computeHealthBadge()
        };
    }
}

class MonitoredEquipmentAsset extends EquipmentAsset {
    private final BigDecimal currentBookValue;
    private final BigDecimal maintenanceSpend;

    public MonitoredEquipmentAsset(int unitId, String assetTag, String serialNumber,
                                   String modelName, String labCode, String status,
                                   BigDecimal acquisitionCost, BigDecimal cumulativeHours,
                                   BigDecimal currentBookValue, BigDecimal maintenanceSpend) {
        super(unitId, assetTag, serialNumber, modelName, labCode, status, acquisitionCost, cumulativeHours);
        this.currentBookValue = currentBookValue != null ? currentBookValue : BigDecimal.ZERO;
        this.maintenanceSpend = maintenanceSpend != null ? maintenanceSpend : BigDecimal.ZERO;
    }

    @Override
    public String computeHealthBadge() {
        if (status.toUpperCase().contains("DECOMMISSION")) return "RETIRED";
        if (maintenanceSpend.compareTo(new BigDecimal("20000")) > 0) return "HIGH_MAINT_COST";
        return super.computeHealthBadge();
    }

    @Override
    public Object[] toTableRow() {
        return new Object[]{
            unitId, assetTag, serialNumber, modelName, labCode,
            status, currentBookValue, cumulativeHours,
            "Maint: " + maintenanceSpend, computeHealthBadge()
        };
    }
}

// ============================================================================
// 3. JDBC CRUD DAO (2 MARKS) & COLLECTIONS (1 MARK)
// ============================================================================
class EquipmentLifecycleDAO {
    private final String url;
    private final String user;
    private final String password;

    public EquipmentLifecycleDAO(String url, String user, String password) {
        this.url = url;
        this.user = "root";
        this.password = "sanidhy";
    }

    private Connection getConnection() throws SQLException {
        return DriverManager.getConnection(url, user, password);
    }

    public boolean isPdfSchema() {
        String checkSql = "SELECT serial_no FROM equipment_unit LIMIT 1";
        try (Connection conn = getConnection();
             PreparedStatement ps = conn.prepareStatement(checkSql);
             ResultSet rs = ps.executeQuery()) {
            return true;
        } catch (SQLException e) {
            return false;
        }
    }

    public List<EquipmentAsset> readAllUnits() throws EquipmentLifecycleException {
        List<EquipmentAsset> units = new ArrayList<>();
        boolean pdf = isPdfSchema();

        String sql = pdf
            ? "SELECT u.unit_id, u.asset_tag, u.serial_no AS serial_col, m.model_name, l.lab_name AS lab_col, u.status, " +
              "COALESCE(pi.unit_cost, 0.00) AS cost_col, u.total_usage_hours AS hrs_col, " +
              "fn_unit_book_value(u.unit_id) AS book_col, " +
              "fn_unit_total_maintenance_cost(u.unit_id) AS maint_col " +
              "FROM equipment_unit u " +
              "JOIN equipment_model m ON u.model_id = m.model_id " +
              "JOIN laboratory l ON u.lab_id = l.lab_id " +
              "LEFT JOIN po_item pi ON u.po_id = pi.po_id AND u.model_id = pi.model_id " +
              "ORDER BY u.unit_id"
            : "SELECT unit_id, asset_tag, serial_number AS serial_col, model_name, lab_code AS lab_col, status, " +
              "acquisition_cost AS cost_col, cumulative_usage_hours AS hrs_col, " +
              "current_book_value AS book_col, total_maintenance_spend AS maint_col " +
              "FROM vw_equipment_lifecycle_summary ORDER BY unit_id";

        try (Connection conn = getConnection();
             PreparedStatement ps = conn.prepareStatement(sql);
             ResultSet rs = ps.executeQuery()) {
            while (rs.next()) {
                units.add(new MonitoredEquipmentAsset(
                    rs.getInt("unit_id"),
                    rs.getString("asset_tag"),
                    rs.getString("serial_col"),
                    rs.getString("model_name"),
                    rs.getString("lab_col"),
                    rs.getString("status"),
                    rs.getBigDecimal("cost_col"),
                    rs.getBigDecimal("hrs_col"),
                    rs.getBigDecimal("book_col"),
                    rs.getBigDecimal("maint_col")
                ));
            }
            return units;
        } catch (SQLException e) {
            throw new EquipmentLifecycleException("Failed to read equipment inventory", e);
        }
    }

    public Set<String> getExistingAssetTags(int excludeUnitId) throws EquipmentLifecycleException {
        Set<String> tags = new HashSet<>();
        String sql = "SELECT asset_tag FROM equipment_unit WHERE unit_id <> ?";
        try (Connection conn = getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, excludeUnitId);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    String t = rs.getString("asset_tag");
                    if (t != null) tags.add(t.toUpperCase());
                }
            }
            return tags;
        } catch (SQLException e) {
            throw new EquipmentLifecycleException("Failed to load asset tag set", e);
        }
    }

    public Map<String, Integer> getStatusDistribution() throws EquipmentLifecycleException {
        Map<String, Integer> statusMap = new LinkedHashMap<>();
        String sql = "SELECT status, COUNT(*) AS cnt FROM equipment_unit GROUP BY status";
        try (Connection conn = getConnection();
             PreparedStatement ps = conn.prepareStatement(sql);
             ResultSet rs = ps.executeQuery()) {
            while (rs.next()) {
                statusMap.put(rs.getString("status"), rs.getInt("cnt"));
            }
            return statusMap;
        } catch (SQLException e) {
            throw new EquipmentLifecycleException("Failed to poll status distribution", e);
        }
    }

    public int createEquipmentUnit(String assetTag, String serialNo, int modelId, int labId, BigDecimal cost)
            throws EquipmentLifecycleException {
        boolean pdf = isPdfSchema();
        String sql = pdf
            ? "INSERT INTO equipment_unit (asset_tag, serial_no, installation_date, status, condition_status, total_usage_hours, model_id, po_id, lab_id) " +
              "VALUES (?, ?, ?, 'available', 'good', 0.00, ?, 1, ?)"
            : "INSERT INTO equipment_unit (asset_tag, serial_number, model_id, current_lab_id, acquisition_date, acquisition_cost, salvage_estimate, status) " +
              "VALUES (?, ?, ?, ?, ?, ?, ?, 'AVAILABLE')";

        try (Connection conn = getConnection();
             PreparedStatement ps = conn.prepareStatement(sql, Statement.RETURN_GENERATED_KEYS)) {
            if (pdf) {
                ps.setString(1, assetTag);
                ps.setString(2, serialNo);
                ps.setDate(3, java.sql.Date.valueOf(LocalDate.now()));
                ps.setInt(4, modelId);
                ps.setInt(5, labId);
            } else {
                ps.setString(1, assetTag);
                ps.setString(2, serialNo);
                ps.setInt(3, modelId);
                ps.setInt(4, labId);
                ps.setDate(5, java.sql.Date.valueOf(LocalDate.now()));
                ps.setBigDecimal(6, cost);
                ps.setBigDecimal(7, cost.multiply(new BigDecimal("0.10")));
            }
            ps.executeUpdate();
            try (ResultSet keys = ps.getGeneratedKeys()) {
                return keys.next() ? keys.getInt(1) : -1;
            }
        } catch (SQLException e) {
            throw new EquipmentLifecycleException("Insert Equipment Unit failed", e);
        }
    }

    // FULL UPDATE: Updates Tag, S/N, ModelID, LabID, Cost (if applicable), Status, and +Hrs
    public int updateEquipmentUnitFull(int unitId, String assetTag, String serialNo,
                                       int modelId, int labId, BigDecimal cost,
                                       String newStatus, BigDecimal addHours)
            throws EquipmentLifecycleException {
        boolean pdf = isPdfSchema();
        String normalizedStatus = pdf
            ? newStatus.toLowerCase().replace("_", " ")
            : newStatus.toUpperCase().replace(" ", "_");
        if (pdf && normalizedStatus.equals("in use")) normalizedStatus = "issued";
        if (pdf && normalizedStatus.equals("calibration due")) normalizedStatus = "under calibration";

        String sql = pdf
            ? "UPDATE equipment_unit SET asset_tag = ?, serial_no = ?, model_id = ?, lab_id = ?, " +
              "status = ?, total_usage_hours = total_usage_hours + ? WHERE unit_id = ?"
            : "UPDATE equipment_unit SET asset_tag = ?, serial_number = ?, model_id = ?, current_lab_id = ?, " +
              "acquisition_cost = ?, salvage_estimate = ?, status = ?, " +
              "cumulative_usage_hours = cumulative_usage_hours + ? WHERE unit_id = ?";

        try (Connection conn = getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            if (pdf) {
                ps.setString(1, assetTag);
                ps.setString(2, serialNo);
                ps.setInt(3, modelId);
                ps.setInt(4, labId);
                ps.setString(5, normalizedStatus);
                ps.setBigDecimal(6, addHours);
                ps.setInt(7, unitId);
            } else {
                ps.setString(1, assetTag);
                ps.setString(2, serialNo);
                ps.setInt(3, modelId);
                ps.setInt(4, labId);
                ps.setBigDecimal(5, cost);
                ps.setBigDecimal(6, cost.multiply(new BigDecimal("0.10")));
                ps.setString(7, normalizedStatus);
                ps.setBigDecimal(8, addHours);
                ps.setInt(9, unitId);
            }
            return ps.executeUpdate();
        } catch (SQLException e) {
            throw new EquipmentLifecycleException("Update Equipment Unit failed", e);
        }
    }

    public int deleteEquipmentUnit(int unitId) throws EquipmentLifecycleException {
        String sql = "DELETE FROM equipment_unit WHERE unit_id = ?";
        try (Connection conn = getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, unitId);
            return ps.executeUpdate();
        } catch (SQLException e) {
            throw new EquipmentLifecycleException("Delete blocked by foreign key history (issue/work order exists)", e);
        }
    }

    public void callIssueEquipmentProcedure(int unitId, int borrowerId, int issuerId, String purpose)
            throws EquipmentLifecycleException {
        String call = "{CALL sp_issue_equipment(?, ?, ?, ?, ?)}";
        try (Connection conn = getConnection();
             CallableStatement cs = conn.prepareCall(call)) {
            cs.setInt(1, unitId);
            cs.setInt(2, borrowerId);
            cs.setInt(3, issuerId);
            cs.setDate(4, java.sql.Date.valueOf(LocalDate.now().plusDays(5)));
            cs.setString(5, purpose);
            cs.execute();
        } catch (SQLException e) {
            throw new EquipmentLifecycleException("Stored Procedure sp_issue_equipment failed", e);
        }
    }
}

// ============================================================================
// 4. SWING GUI (1 MARK) & MULTITHREADED TELEMETRY MONITOR (1 MARK)
// ============================================================================
public class LelmsFullProject extends JFrame {
    // PUT YOUR MYSQL ROOT PASSWORD IN THE 3RD ARGUMENT BELOW:
    private final EquipmentLifecycleDAO dao = new EquipmentLifecycleDAO(
        "jdbc:mysql://localhost:3306/lab_equipment_lms", "root", "sanidhy"
    );

    private static final Pattern ASSET_TAG_PATTERN = Pattern.compile("^AST-[A-Z]{2,6}-[0-9]{3}$");

    private final DefaultTableModel tableModel = new DefaultTableModel(
        new String[]{"Unit ID", "Asset Tag", "Serial No", "Model", "Lab", "Status", "Book Value", "Hours", "Maint Spend", "Health Badge"}, 0
    ) {
        @Override
        public boolean isCellEditable(int row, int column) {
            return false;
        }
    };

    private final JTable table = new JTable(tableModel);
    private final JLabel lblMonitorStatus = new JLabel("Initializing background telemetry thread...");

    private final JTextField tfUnitId = new JTextField(4);
    private final JTextField tfAssetTag = new JTextField("AST-ECE-008", 10);
    private final JTextField tfSerial = new JTextField("SN-KEY-9908A", 10);
    private final JTextField tfModelId = new JTextField("1", 3);
    private final JTextField tfLabId = new JTextField("1", 3);
    private final JTextField tfCost = new JTextField("150000", 7);
    private final JComboBox<String> cbStatus = new JComboBox<>(new String[]{
        "AVAILABLE", "IN_USE", "UNDER_MAINTENANCE", "CALIBRATION_DUE", "DECOMMISSIONED"
    });
    private final JTextField tfAddHours = new JTextField("0.0", 4);

    public LelmsFullProject() {
        super("Laboratory Equipment Lifecycle & Maintenance System (JDBC + Swing)");
        setSize(1220, 620);
        setDefaultCloseOperation(EXIT_ON_CLOSE);
        setLayout(new BorderLayout(8, 8));

        table.setRowHeight(25);
        table.setSelectionMode(ListSelectionModel.SINGLE_SELECTION);
        table.getSelectionModel().addListSelectionListener(e -> {
            if (!e.getValueIsAdjusting() && table.getSelectedRow() != -1) {
                int row = table.getSelectedRow();
                tfUnitId.setText(String.valueOf(table.getValueAt(row, 0)));
                tfAssetTag.setText(String.valueOf(table.getValueAt(row, 1)));
                tfSerial.setText(String.valueOf(table.getValueAt(row, 2)));
                String rowStatus = String.valueOf(table.getValueAt(row, 5)).toUpperCase().replace(" ", "_");
                if (rowStatus.equals("ISSUED")) rowStatus = "IN_USE";
                if (rowStatus.equals("UNDER_CALIBRATION")) rowStatus = "CALIBRATION_DUE";
                cbStatus.setSelectedItem(rowStatus);
            }
        });
        add(new JScrollPane(table), BorderLayout.CENTER);

        JPanel crudContainer = new JPanel(new GridLayout(2, 1, 4, 6));
        crudContainer.setBorder(BorderFactory.createTitledBorder("JDBC CRUD & Stored Procedure Operations (Click any table row to auto-fill fields)"));

        JPanel inputRow = new JPanel(new FlowLayout(FlowLayout.LEFT, 8, 4));
        inputRow.add(new JLabel("ID:")); inputRow.add(tfUnitId);
        inputRow.add(new JLabel("Tag:")); inputRow.add(tfAssetTag);
        inputRow.add(new JLabel("S/N:")); inputRow.add(tfSerial);
        inputRow.add(new JLabel("ModelID:")); inputRow.add(tfModelId);
        inputRow.add(new JLabel("LabID:")); inputRow.add(tfLabId);
        inputRow.add(new JLabel("Cost:")); inputRow.add(tfCost);
        inputRow.add(new JLabel("Status:")); inputRow.add(cbStatus);
        inputRow.add(new JLabel("+Hrs:")); inputRow.add(tfAddHours);

        JPanel buttonRow = new JPanel(new FlowLayout(FlowLayout.LEFT, 10, 4));
        JButton btnCreate = new JButton("Create (INSERT)");
        JButton btnRead   = new JButton("Refresh (SELECT)");
        JButton btnUpdate = new JButton("Update (UPDATE)");
        JButton btnDelete = new JButton("Delete (DELETE)");
        JButton btnProcIssue = new JButton("Issue Selected Unit (CALL SP)");

        btnCreate.addActionListener(e -> handleCreate());
        btnRead.addActionListener(e -> refreshTableAsync());
        btnUpdate.addActionListener(e -> handleUpdate());
        btnDelete.addActionListener(e -> handleDelete());
        btnProcIssue.addActionListener(e -> handleIssueProcedure());

        buttonRow.add(btnCreate);
        buttonRow.add(btnRead);
        buttonRow.add(btnUpdate);
        buttonRow.add(btnDelete);
        buttonRow.add(btnProcIssue);

        crudContainer.add(inputRow);
        crudContainer.add(buttonRow);
        add(crudContainer, BorderLayout.NORTH);

        JPanel southPanel = new JPanel(new BorderLayout());
        southPanel.setBorder(BorderFactory.createEmptyBorder(6, 10, 6, 10));
        southPanel.add(lblMonitorStatus, BorderLayout.CENTER);
        add(southPanel, BorderLayout.SOUTH);

        refreshTableAsync();
        startBackgroundHealthThread();
    }

    private int resolveTargetUnitId() {
        String idText = tfUnitId.getText().trim();
        if (!idText.isEmpty()) {
            try {
                return Integer.parseInt(idText);
            } catch (NumberFormatException nfe) {
                throw new InvalidEquipmentInputException("Unit ID must be a valid integer (found: '" + idText + "').");
            }
        }
        int selectedRow = table.getSelectedRow();
        if (selectedRow != -1) {
            Object val = table.getValueAt(selectedRow, 0);
            tfUnitId.setText(String.valueOf(val));
            return Integer.parseInt(String.valueOf(val));
        }
        throw new InvalidEquipmentInputException("Select a row in the table or enter a Unit ID in the 'ID:' box first.");
    }

    private void handleCreate() {
        try {
            String tag = tfAssetTag.getText().trim().toUpperCase();
            String serial = tfSerial.getText().trim().toUpperCase();

            if (tag.isEmpty() || serial.isEmpty()) {
                throw new InvalidEquipmentInputException("Asset Tag and Serial Number cannot be blank.");
            }
            if (!ASSET_TAG_PATTERN.matcher(tag).matches()) {
                throw new InvalidEquipmentInputException("Asset Tag must match format AST-DEPT-NNN (e.g., AST-ECE-008).");
            }

            Set<String> existingTags = dao.getExistingAssetTags(-1);
            if (existingTags.contains(tag)) {
                throw new InvalidEquipmentInputException("Asset Tag '" + tag + "' already exists in the database.");
            }

            int modelId = Integer.parseInt(tfModelId.getText().trim());
            int labId = Integer.parseInt(tfLabId.getText().trim());
            BigDecimal cost = new BigDecimal(tfCost.getText().trim());

            int newId = dao.createEquipmentUnit(tag, serial, modelId, labId, cost);
            tfUnitId.setText(String.valueOf(newId));
            JOptionPane.showMessageDialog(this, "Created Equipment Unit ID: " + newId, "Insert Success", JOptionPane.INFORMATION_MESSAGE);
            refreshTableAsync();
        } catch (InvalidEquipmentInputException | NumberFormatException valEx) {
            JOptionPane.showMessageDialog(this, valEx.getMessage(), "Input Validation Error", JOptionPane.WARNING_MESSAGE);
        } catch (EquipmentLifecycleException dbEx) {
            JOptionPane.showMessageDialog(this, dbEx.getDiagnosticSummary(), "Database Error", JOptionPane.ERROR_MESSAGE);
        }
    }

    private void handleUpdate() {
        try {
            int unitId = resolveTargetUnitId();
            String tag = tfAssetTag.getText().trim().toUpperCase();
            String serial = tfSerial.getText().trim().toUpperCase();

            if (tag.isEmpty() || serial.isEmpty()) {
                throw new InvalidEquipmentInputException("Asset Tag and Serial Number cannot be blank.");
            }
            if (!ASSET_TAG_PATTERN.matcher(tag).matches()) {
                throw new InvalidEquipmentInputException("Asset Tag must match format AST-DEPT-NNN (e.g., AST-ECE-008).");
            }

            Set<String> otherTags = dao.getExistingAssetTags(unitId);
            if (otherTags.contains(tag)) {
                throw new InvalidEquipmentInputException("Asset Tag '" + tag + "' is already used by another unit.");
            }

            int modelId = Integer.parseInt(tfModelId.getText().trim());
            int labId = Integer.parseInt(tfLabId.getText().trim());
            BigDecimal cost = new BigDecimal(tfCost.getText().trim());
            BigDecimal addHours = new BigDecimal(tfAddHours.getText().trim());

            if (addHours.compareTo(BigDecimal.ZERO) < 0) {
                throw new InvalidEquipmentInputException("Added usage hours cannot be negative.");
            }

            int rows = dao.updateEquipmentUnitFull(
                unitId, tag, serial, modelId, labId, cost,
                (String) cbStatus.getSelectedItem(), addHours
            );
            JOptionPane.showMessageDialog(this,
                "Updated Unit ID " + unitId + " (Tag: " + tag + ", S/N: " + serial + ", Status: " + cbStatus.getSelectedItem() + ", Rows: " + rows + ").",
                "Update Success", JOptionPane.INFORMATION_MESSAGE);
            refreshTableAsync();
        } catch (InvalidEquipmentInputException | NumberFormatException valEx) {
            JOptionPane.showMessageDialog(this, valEx.getMessage(), "Validation Error", JOptionPane.WARNING_MESSAGE);
        } catch (EquipmentLifecycleException dbEx) {
            JOptionPane.showMessageDialog(this, dbEx.getDiagnosticSummary(), "Database Update Error", JOptionPane.ERROR_MESSAGE);
        }
    }

    private void handleDelete() {
        try {
            int unitId = resolveTargetUnitId();
            int confirm = JOptionPane.showConfirmDialog(
                this,
                "Are you sure you want to delete Equipment Unit ID " + unitId + "?",
                "Confirm Delete",
                JOptionPane.YES_NO_OPTION
            );
            if (confirm != JOptionPane.YES_OPTION) return;

            int rows = dao.deleteEquipmentUnit(unitId);
            tfUnitId.setText("");
            JOptionPane.showMessageDialog(this, "Deleted Unit ID " + unitId + " (Rows affected: " + rows + ").", "Delete Success", JOptionPane.INFORMATION_MESSAGE);
            refreshTableAsync();
        } catch (InvalidEquipmentInputException valEx) {
            JOptionPane.showMessageDialog(this, valEx.getMessage(), "Selection Required", JOptionPane.WARNING_MESSAGE);
        } catch (EquipmentLifecycleException dbEx) {
            JOptionPane.showMessageDialog(this, dbEx.getDiagnosticSummary(), "Referential Integrity Guard", JOptionPane.ERROR_MESSAGE);
        }
    }

    private void handleIssueProcedure() {
        try {
            int unitId = resolveTargetUnitId();
            dao.callIssueEquipmentProcedure(unitId, 7, 1, "GUI JDBC CallableStatement Checkout");
            JOptionPane.showMessageDialog(this,
                "Executed CALL sp_issue_equipment for Unit ID " + unitId + " (Status -> IN_USE / issued).",
                "Stored Procedure Executed", JOptionPane.INFORMATION_MESSAGE);
            refreshTableAsync();
        } catch (InvalidEquipmentInputException valEx) {
            JOptionPane.showMessageDialog(this, valEx.getMessage(), "Selection Required", JOptionPane.WARNING_MESSAGE);
        } catch (EquipmentLifecycleException dbEx) {
            JOptionPane.showMessageDialog(this, dbEx.getDiagnosticSummary(), "Procedure Execution Error", JOptionPane.ERROR_MESSAGE);
        }
    }

    private void refreshTableAsync() {
        new Thread(() -> {
            try {
                List<EquipmentAsset> list = dao.readAllUnits();
                SwingUtilities.invokeLater(() -> {
                    tableModel.setRowCount(0);
                    for (EquipmentAsset asset : list) {
                        tableModel.addRow(asset.toTableRow());
                    }
                });
            } catch (EquipmentLifecycleException ex) {
                SwingUtilities.invokeLater(() ->
                    lblMonitorStatus.setText("DB Error: " + ex.getDiagnosticSummary())
                );
            }
        }).start();
    }

    private void startBackgroundHealthThread() {
        Thread monitorThread = new Thread(() -> {
            while (!Thread.currentThread().isInterrupted()) {
                try {
                    Map<String, Integer> dist = dao.getStatusDistribution();
                    SwingUtilities.invokeLater(() ->
                        lblMonitorStatus.setText("Live Status Summary (Background Daemon Thread): " + dist)
                    );
                    Thread.sleep(15000);
                } catch (InterruptedException ie) {
                    Thread.currentThread().interrupt();
                } catch (EquipmentLifecycleException ex) {
                    SwingUtilities.invokeLater(() ->
                        lblMonitorStatus.setText("Telemetry Warning: " + ex.getDiagnosticSummary())
                    );
                    try { Thread.sleep(15000); } catch (InterruptedException ie) { break; }
                }
            }
        }, "LELMS-Health-Monitor-Thread");
        monitorThread.setDaemon(true);
        monitorThread.start();
    }

    public static void main(String[] args) {
        SwingUtilities.invokeLater(() -> new LelmsFullProject().setVisible(true));
    }
}
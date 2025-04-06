module vending_machine(
    input clk, rst,
    input [1:0] coin,
    input req,
    output reg disp,
    output reg [5:0] change
);

    parameter [1:0] IDLE = 2'b00, COLLECT = 2'b01, DISP = 2'b10;
    reg [1:0] state, next;
    reg [5:0] count;
    reg [1:0] prevcoin;
    wire coin_inserted = (coin != 0) && (prevcoin == 0);

    // State transition logic
    always @(*) begin
        case(state)
            IDLE    : next = (coin != 0) ? COLLECT : IDLE;
            COLLECT : next = (count >= 25 && req) ? DISP : COLLECT;
            DISP    : next = IDLE;
            default : next = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            count <= 0;
            prevcoin <= 0;
        end else begin
            prevcoin <= coin; // Update previous coin value
            state <= next;

            // Handle first coin insertion (IDLE → COLLECT)
            if (state == IDLE && next == COLLECT) begin
                case(coin)
                    2'b01: count <= 5;
                    2'b10: count <= 10;
                    2'b11: count <= 20;
                    default: count <= count;
                endcase
            end
            // Handle subsequent coins in COLLECT state
            else if (state == COLLECT && coin_inserted) begin
                case(coin)
                    2'b01: count <= count + 5;
                    2'b10: count <= count + 10;
                    2'b11: count <= count + 20;
                    default: count <= count;
                endcase
            end
            else if (state == DISP) 
                count <= 0;
        end
    end

    // Output logic
    always @(*) begin
        disp = (state == DISP);
        change = (state == DISP && count > 25) ? count - 25 : 0;
    end

endmodule


module tb_vending_machine();

    reg clk, rst;
    reg [1:0] coin;
    reg req;
    wire disp;
    wire [5:0] change;

    // Instantiate the vending machine
  vending_machine uut (
        .clk(clk),
        .rst(rst),
        .coin(coin),
        .req(req),
        .disp(disp),
        .change(change)
    );

    // Generate clock signal (10ns period)
    always #5 clk = ~clk;

    // Test sequence
    initial begin
        // Initialize inputs
        clk = 0;
        rst = 1;
        coin = 2'b00;
        req = 0;

        // Apply reset
        #10 rst = 0;

        // Test Case 1: Exact payment (₹25)
        #10 coin = 2'b01; // ₹5
        #10 coin = 2'b00; // Release coin
        #10 coin = 2'b10; // ₹10
        #10 coin = 2'b00;
        #10 coin = 2'b10; // Another ₹10 (Total = 25)
        #10 coin = 2'b00;
        #10 req = 1;      // Request product
        #10 req = 0;

        // Test Case 2: Overpayment (₹30)
        #20 coin = 2'b11; // ₹20
        #10 coin = 2'b00;
        #10 coin = 2'b10; // ₹10 (Total = 30)
        #10 coin = 2'b00;
        #10 req = 1;
        #10 req = 0;

        // Test Case 3: Underpayment (₹15)
        #20 coin = 2'b01; // ₹5
        #10 coin = 2'b00;
        #10 coin = 2'b10; // ₹10 (Total = 15)
        #10 coin = 2'b00;
        #10 req = 1;      // Should NOT dispense
        #10 req = 0;

        // Test Case 4: Multiple requests
        #20 coin = 2'b11; // ₹20
        #10 coin = 2'b00;
        #10 req = 1;      // Request before enough money (Total = 20)
        #10 req = 0;
        #10 coin = 2'b11; // ₹20 (Total = 40)
        #10 coin = 2'b00;
        #10 req = 1;

        #50 $finish;
    end

    // Monitor results
    initial begin
        $monitor("Time=%0tns | State=%s | Coin=%b | Req=%b | Disp=%b | Change=%0d | Count=%0d",
            $time,
            uut.state == 2'b00 ? "IDLE" : 
            uut.state == 2'b01 ? "COLLECT" : "DISP",
            coin, req, disp, change, uut.count);
    end

endmodule

/*
# KERNEL: Time=0ns | State=   @@@@ | Coin=00 | Req=0 | Disp=x | Change=x | Count=x
# KERNEL: Time=5ns | State=   IDLE | Coin=00 | Req=0 | Disp=0 | Change=0 | Count=0
# KERNEL: Time=20ns | State=   IDLE | Coin=01 | Req=0 | Disp=0 | Change=0 | Count=0
# KERNEL: Time=25ns | State=COLLECT | Coin=01 | Req=0 | Disp=0 | Change=0 | Count=5
# KERNEL: Time=30ns | State=COLLECT | Coin=00 | Req=0 | Disp=0 | Change=0 | Count=5
# KERNEL: Time=40ns | State=COLLECT | Coin=10 | Req=0 | Disp=0 | Change=0 | Count=5
# KERNEL: Time=45ns | State=COLLECT | Coin=10 | Req=0 | Disp=0 | Change=0 | Count=15
# KERNEL: Time=50ns | State=COLLECT | Coin=00 | Req=0 | Disp=0 | Change=0 | Count=15
# KERNEL: Time=60ns | State=COLLECT | Coin=10 | Req=0 | Disp=0 | Change=0 | Count=15
# KERNEL: Time=65ns | State=COLLECT | Coin=10 | Req=0 | Disp=0 | Change=0 | Count=25
# KERNEL: Time=70ns | State=COLLECT | Coin=00 | Req=0 | Disp=0 | Change=0 | Count=25
# KERNEL: Time=80ns | State=COLLECT | Coin=00 | Req=1 | Disp=0 | Change=0 | Count=25
# KERNEL: Time=85ns | State=   DISP | Coin=00 | Req=1 | Disp=1 | Change=0 | Count=25
# KERNEL: Time=90ns | State=   DISP | Coin=00 | Req=0 | Disp=1 | Change=0 | Count=25
# KERNEL: Time=95ns | State=   IDLE | Coin=00 | Req=0 | Disp=0 | Change=0 | Count=0
# KERNEL: Time=110ns | State=   IDLE | Coin=11 | Req=0 | Disp=0 | Change=0 | Count=0
# KERNEL: Time=115ns | State=COLLECT | Coin=11 | Req=0 | Disp=0 | Change=0 | Count=20
# KERNEL: Time=120ns | State=COLLECT | Coin=00 | Req=0 | Disp=0 | Change=0 | Count=20
# KERNEL: Time=130ns | State=COLLECT | Coin=10 | Req=0 | Disp=0 | Change=0 | Count=20
# KERNEL: Time=135ns | State=COLLECT | Coin=10 | Req=0 | Disp=0 | Change=0 | Count=30
# KERNEL: Time=140ns | State=COLLECT | Coin=00 | Req=0 | Disp=0 | Change=0 | Count=30
# KERNEL: Time=150ns | State=COLLECT | Coin=00 | Req=1 | Disp=0 | Change=0 | Count=30
# KERNEL: Time=155ns | State=   DISP | Coin=00 | Req=1 | Disp=1 | Change=5 | Count=30
# KERNEL: Time=160ns | State=   DISP | Coin=00 | Req=0 | Disp=1 | Change=5 | Count=30
# KERNEL: Time=165ns | State=   IDLE | Coin=00 | Req=0 | Disp=0 | Change=0 | Count=0
# KERNEL: Time=180ns | State=   IDLE | Coin=01 | Req=0 | Disp=0 | Change=0 | Count=0
# KERNEL: Time=185ns | State=COLLECT | Coin=01 | Req=0 | Disp=0 | Change=0 | Count=5
# KERNEL: Time=190ns | State=COLLECT | Coin=00 | Req=0 | Disp=0 | Change=0 | Count=5
# KERNEL: Time=200ns | State=COLLECT | Coin=10 | Req=0 | Disp=0 | Change=0 | Count=5
# KERNEL: Time=205ns | State=COLLECT | Coin=10 | Req=0 | Disp=0 | Change=0 | Count=15
# KERNEL: Time=210ns | State=COLLECT | Coin=00 | Req=0 | Disp=0 | Change=0 | Count=15
# KERNEL: Time=220ns | State=COLLECT | Coin=00 | Req=1 | Disp=0 | Change=0 | Count=15
# KERNEL: Time=230ns | State=COLLECT | Coin=00 | Req=0 | Disp=0 | Change=0 | Count=15
# KERNEL: Time=250ns | State=COLLECT | Coin=11 | Req=0 | Disp=0 | Change=0 | Count=15
# KERNEL: Time=255ns | State=COLLECT | Coin=11 | Req=0 | Disp=0 | Change=0 | Count=35
# KERNEL: Time=260ns | State=COLLECT | Coin=00 | Req=0 | Disp=0 | Change=0 | Count=35
# KERNEL: Time=270ns | State=COLLECT | Coin=00 | Req=1 | Disp=0 | Change=0 | Count=35
# KERNEL: Time=275ns | State=   DISP | Coin=00 | Req=1 | Disp=1 | Change=10 | Count=35
# KERNEL: Time=280ns | State=   DISP | Coin=00 | Req=0 | Disp=1 | Change=10 | Count=35
# KERNEL: Time=285ns | State=   IDLE | Coin=00 | Req=0 | Disp=0 | Change=0 | Count=0
# KERNEL: Time=290ns | State=   IDLE | Coin=11 | Req=0 | Disp=0 | Change=0 | Count=0
# KERNEL: Time=295ns | State=COLLECT | Coin=11 | Req=0 | Disp=0 | Change=0 | Count=20
# KERNEL: Time=300ns | State=COLLECT | Coin=00 | Req=0 | Disp=0 | Change=0 | Count=20
# KERNEL: Time=310ns | State=COLLECT | Coin=00 | Req=1 | Disp=0 | Change=0 | Count=20
# RUNTIME: Info: RUNTIME_0068 testbench.sv (68): $finish called
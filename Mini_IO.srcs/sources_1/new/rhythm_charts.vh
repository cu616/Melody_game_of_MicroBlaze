// Generated from charts/*.chart. Edit those text files, then run scripts/generate_charts.ps1.
function [2:0] chart_row;
    input [1:0] song;
    input [7:0] step;
    begin
        if (song == 2'd1) begin
            case (step[5:0])
                6'd0: chart_row = 3'b010;
                6'd4: chart_row = 3'b010;
                6'd8: chart_row = 3'b001;
                6'd12: chart_row = 3'b010;
                6'd16: chart_row = 3'b100;
                6'd20: chart_row = 3'b100;
                6'd24: chart_row = 3'b001;
                6'd28: chart_row = 3'b100;
                6'd32: chart_row = 3'b010;
                6'd36: chart_row = 3'b001;
                6'd40: chart_row = 3'b100;
                6'd44: chart_row = 3'b010;
                6'd48: chart_row = 3'b010;
                6'd52: chart_row = 3'b001;
                6'd56: chart_row = 3'b100;
                6'd60: chart_row = 3'b010;
                default: chart_row = 3'b000;
            endcase
        end else begin
            case (step[5:0])
                6'd0: chart_row = 3'b010;
                6'd4: chart_row = 3'b001;
                6'd8: chart_row = 3'b100;
                6'd12: chart_row = 3'b010;
                6'd16: chart_row = 3'b001;
                6'd20: chart_row = 3'b010;
                6'd24: chart_row = 3'b100;
                6'd28: chart_row = 3'b011;
                6'd32: chart_row = 3'b010;
                6'd36: chart_row = 3'b100;
                6'd40: chart_row = 3'b001;
                6'd44: chart_row = 3'b010;
                6'd48: chart_row = 3'b100;
                6'd52: chart_row = 3'b010;
                6'd56: chart_row = 3'b101;
                6'd60: chart_row = 3'b010;
                default: chart_row = 3'b000;
            endcase
        end
    end
endfunction

function [2:0] chart_hold_row;
    input [1:0] song;
    input [7:0] step;
    begin
        if (song == 2'd1) begin
            case (step[5:0])
                6'd12: chart_hold_row = 3'b010;
                6'd44: chart_hold_row = 3'b100;
                default: chart_hold_row = 3'b000;
            endcase
        end else begin
            case (step[5:0])
                6'd20: chart_hold_row = 3'b010;
                6'd48: chart_hold_row = 3'b100;
                default: chart_hold_row = 3'b000;
            endcase
        end
    end
endfunction

function [5:0] chart_hold_len;
    input [1:0] song;
    input [7:0] step;
    begin
        if (song == 2'd1) begin
            case (step[5:0])
                6'd12: chart_hold_len = 6'd24;
                6'd44: chart_hold_len = 6'd24;
                default: chart_hold_len = 6'd0;
            endcase
        end else begin
            case (step[5:0])
                6'd20: chart_hold_len = 6'd24;
                6'd48: chart_hold_len = 6'd24;
                default: chart_hold_len = 6'd0;
            endcase
        end
    end
endfunction

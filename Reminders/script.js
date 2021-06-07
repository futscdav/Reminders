
function onOpen() {
    var ui = SpreadsheetApp.getUi();
    ui.createMenu('Echo Options')
        .addItem('Import from Reminders', 'MRImport')
        .addItem('Export to Reminders', 'MRExportProper')
        .addItem('Open Raid Select', 'showDialog')
        .addToUi();
  }
  
  function deserialize_string(string) {
    // for now, just format the space
    var formatted = string.toString().replace(/(\~\`)/g, ' ');
    return formatted;
  }
  
  function deserialize_value(pattern, string, control, data) {
    //console.log(control);
    switch(control)
    {
      case "^^":
        return;
      case "^S":
        return deserialize_string(data);
      case "^N":
        return data; 
      case "^F":
        return "NOT YET IMPLEMENTED PLEASE REVISIT";
      case "^B":
        return true;
      case "^b":
        return false;
      case "^Z":
        return 'nil';
      case "^T":
        var res = new Object();
        while (true)
        {
         var match = pattern.exec(string);
         if (match[1] == "^t")
           break;
         
         var k = deserialize_value(pattern, string, match[1], match[2]);
         match = pattern.exec(string);
         var v = deserialize_value(pattern, string, match[1], match[2]);
         
         //console.log("key " + k + " value " + v);
          res[k] = v;
        }
        //console.log("returning table");
        return res;
    }
    
  }
  
  function deserialize_reminder(serialized) {
    // strip §REMINDER$
    serialized = serialized.substring(9);
    var pattern = /(\^.)([^^]*)/g;
    pattern.lastIndex = 0;
  
    var match;
    // rev
    pattern.exec(serialized);
    // reminder table
    match = pattern.exec(serialized);
    return deserialize_value(pattern, serialized, match[1], match[2]);
  }
  
  function MRImport() {
    var sheet = SpreadsheetApp.getActiveSheet();
  
    const valueof = function(row, col) {
        return sheet.getRange(row, col).getValue();
    }
    const setval = function(row, col, val) {
        // console.log("set " + val + " to " + col)
        sheet.getRange(row, col).setValue(val);
    }
  
    var meta_sheet = SpreadsheetApp.getActive().getSheetByName('HiddenValues');
    var col_indirect = 2;
    const indirect_valueof = function(row) {
        return meta_sheet.getRange(row, col_indirect).getValue();
    }
  
    var importstring = sheet.getRange(1, indirect_valueof(36)).getValue();
    var split = importstring.split("§");
    var numreminders = split.length;
  
    var first_row = indirect_valueof(2);
    var col_enabled = indirect_valueof(3);
    var col_name = indirect_valueof(4);
    var col_category = indirect_valueof(5);
    var col_subcategory = indirect_valueof(6);
    var col_message = indirect_valueof(7);
    var col_duration = indirect_valueof(8);
    var col_delay = indirect_valueof(9);
    var col_who = indirect_valueof(11);
    var col_sound = indirect_valueof(12);
    var col_difficulty = indirect_valueof(13);
    var col_trigger = indirect_valueof(14);
    var col_event = indirect_valueof(15);
    var col_only_load_phase = indirect_valueof(16);
    var col_only_load_phase_num = indirect_valueof(17);
    var col_bw_phase = indirect_valueof(18);
    var col_bw_bar_check_text = indirect_valueof(19);
    var col_bw_bar_text = indirect_valueof(20);
    var col_bw_bar_check_spell = indirect_valueof(21);
    var col_bw_bar_spell = indirect_valueof(22);
    var col_bw_bar_before = indirect_valueof(23);
    var col_event_check_source = indirect_valueof(24);
    var col_event_check_target = indirect_valueof(25);
    var col_event_check_spell = indirect_valueof(26);
    var col_event_source = indirect_valueof(27);
    var col_event_target = indirect_valueof(28);
    var col_event_spell = indirect_valueof(29);
    var col_event_hp_unit = indirect_valueof(30);
    var col_event_hp = indirect_valueof(31);
    var col_send_aura_check = indirect_valueof(32);
    var col_send_aura = indirect_valueof(33);
    var col_repeat = indirect_valueof(34);
    var col_repeat_number = indirect_valueof(37);
    var col_repeat_offset = indirect_valueof(38);
    var col_repeat_mod = indirect_valueof(39);
    var col_check_stacks = indirect_valueof(40);
    var col_stacks_operator = indirect_valueof(41);
    var col_stacks_number = indirect_valueof(42);
    
    var next_free_row = first_row;
    while (valueof(next_free_row, col_name) != "") {
        next_free_row++;
    }
    console.log("First available row is " + next_free_row);
  
    for (var i = 0; i < numreminders; i++) {
      var deserialized = deserialize_reminder(split[i]);
      console.log("Importing " + deserialized.name);
      // check if the reminder with this name is already in the table
      var row = next_free_row;
      for (var check = first_row; check < next_free_row; check++) {
          if (deserialized.name == valueof(check, col_name)) {
            console.log("Name already exists, overwrite row");
            row = check;
            break;
          }
      }
      if (row == next_free_row) {
          next_free_row++;
      }
      
      // minor fix ...
      if (deserialized.trigger_opt.only_load_phase == null) {
          deserialized.trigger_opt.only_load_phase = false; 
      }
      if (deserialized.trigger_opt.bw_bar_check_text == null) {
          deserialized.trigger_opt.bw_bar_check_text = false; 
      }
      if (deserialized.trigger_opt.bw_bar_check_spellid == null) {
          deserialized.trigger_opt.bw_bar_check_spellid = false; 
      }
      if (deserialized.trigger_opt.check_source == null) {
          deserialized.trigger_opt.check_source = false; 
      }
      if (deserialized.trigger_opt.check_dest == null) {
          deserialized.trigger_opt.check_dest = false; 
      }
      if (deserialized.trigger_opt.check_name == null) {
          deserialized.trigger_opt.check_name = false; 
      }
      if (deserialized.notification.check_for_aura == null) {
          deserialized.notification.check_for_aura = false; 
      }
      if (deserialized.trigger_opt.check_stacks == null) {
          deserialized.trigger_opt.check_stacks = false; 
      }
      
  
      setval(row, col_name, deserialized.name);
      setval(row, col_category, deserialized.category);
      setval(row, col_subcategory, deserialized.subcategory);
      setval(row, col_message, deserialized.notification.message);
      setval(row, col_duration, deserialized.notification.duration);
      setval(row, col_delay, deserialized.delay.delay_sec);
      setval(row, col_who, deserialized.notification.who);
      setval(row, col_sound, deserialized.notification.sound);
      setval(row, col_difficulty, deserialized.trigger_opt.difficulty);
      setval(row, col_enabled, deserialized.enabled);
      setval(row, col_trigger, deserialized.trigger);
      setval(row, col_only_load_phase, deserialized.trigger_opt.only_load_phase);
      setval(row, col_only_load_phase_num, deserialized.trigger_opt.only_load_phase_num);
      setval(row, col_bw_phase, deserialized.trigger_opt.bw_phase);
      setval(row, col_bw_bar_check_text, deserialized.trigger_opt.bw_bar_check_text);
      setval(row, col_bw_bar_text, deserialized.trigger_opt.bw_bar_text);
      setval(row, col_bw_bar_check_spell, deserialized.trigger_opt.bw_bar_check_spellid);
      setval(row, col_bw_bar_spell, deserialized.trigger_opt.bw_bar_spellid);
      setval(row, col_bw_bar_before, deserialized.trigger_opt.bw_bar_before);
      setval(row, col_event, deserialized.trigger_opt.event);
      setval(row, col_event_check_source, deserialized.trigger_opt.check_source);
      setval(row, col_event_check_target, deserialized.trigger_opt.check_dest);
      setval(row, col_event_check_spell, deserialized.trigger_opt.check_name);
      setval(row, col_event_source, deserialized.trigger_opt.source_name);
      setval(row, col_event_target, deserialized.trigger_opt.dest_name);
      setval(row, col_event_spell, deserialized.trigger_opt.name);
      setval(row, col_event_hp_unit, deserialized.trigger_opt.boss_hp_unit);
      setval(row, col_event_hp, deserialized.trigger_opt.boss_hp_pct);
      setval(row, col_send_aura_check, deserialized.notification.check_for_aura);
      setval(row, col_send_aura, deserialized.notification.aura_to_check);
      setval(row, col_repeat, deserialized.repeats.setup);
      setval(row, col_repeat_number, deserialized.repeats.number);
      setval(row, col_repeat_offset, deserialized.repeats.offset);
      setval(row, col_repeat_mod, deserialized.repeats.modulo);
      setval(row, col_check_stacks, deserialized.trigger_opt.check_stacks);
      setval(row, col_stacks_operator, deserialized.trigger_opt.stacks_op)
      setval(row, col_stacks_number, deserialized.trigger_opt.stacks_count);
    }
  
  }
  
  function encode_utf8( s ){
      return ( encodeURI( s ) );
  }
  
  function Replacer(match) {
      var n = match.charCodeAt(0);
      // console.log("replacing " + match.charCodeAt(0));
      /*if (n == 30) {
          return "\x7E\x7A"}
      else*/ if (n <= 32) {
          return "\x7E" + String.fromCharCode(n+64)}
      /*else if (n==94){
          return "\x7E\x7D"}
      else if (n==126){
          return "\x7E\x7C"}
      else if (n==127){
          return "\x7E\x7B"}*/
    else {
      return match
    }
  }
  
  function FormatString(original) {
    var formatted = original;//encode_utf8(original);
    formatted = original.toString().replace(/([\x20])/g, Replacer);
    return (formatted);
  }
  
  function EncodeBool(boolean) {
    return boolean==true?"B":"b"; 
  }
  
  function typeOf (obj) {
    return {}.toString.call(obj).split(' ')[1].slice(0, -1).toLowerCase();
  }
  
  function serialize_value(value) {
    var type = typeOf(value);
    switch(type){
      case 'string':
        return "^S" + FormatString(value);
      case 'boolean':
        return "^" + EncodeBool(value);
      case 'object':
        if (value == undefined) {
            return serialize_value(false);
        }
        var res = ""
        var key;
        for (key in value) {
          // because js key in object cannot be a number, try converting the string to number here
          // so make sure real keys dont start with a number..
          var try_int = parseInt(key);
          if (!isNaN(try_int)) {
              key = try_int;
          }
          var tkey = serialize_value(key);
          var tval = serialize_value(value[key]);
          if (tval != "^Sundefined") {
            res += tkey + tval; 
          } else {
              // res += tkey + "^Z";
          }
        }
        return "^T" + res + "^t";
      case 'number':
        return "^N" + value;
      default:
        console.log('type error ' + type);
    }
  }
  
  function serialize_reminder(reminder) {
    var prefix = "REMINDER$";
    var rev = "^1";
    var end = "^^";
    
    var table = serialize_value(reminder);
    
    return prefix + rev + table + end;
  }
  
  function lzw_encode(s) {
      var dict = {};
      var data = (s + "").split("");
      var out = [];
      var currChar;
      var phrase = data[0];
      var code = 256;
      for (var i=1; i<data.length; i++) {
          currChar=data[i];
          if (dict[phrase + currChar] != null) {
              phrase += currChar;
          }
          else {
              out.push(phrase.length > 1 ? dict[phrase] : phrase.charCodeAt(0));
              dict[phrase + currChar] = code;
              code++;
              phrase=currChar;
          }
      }
      out.push(phrase.length > 1 ? dict[phrase] : phrase.charCodeAt(0));
      for (var i=0; i<out.length; i++) {
          out[i] = String.fromCharCode(out[i]);
      }
      return out.join("");
  }
  
  function MRExportProper() {
    // put it into 1, 15
    var sheet = SpreadsheetApp.getActiveSheet();
    var names = [];
    var exported = [];
  
    const valueof = function(row, col) {
        return sheet.getRange(row, col).getValue();
    }
  
    var meta_sheet = SpreadsheetApp.getActive().getSheetByName('HiddenValues');
    const metavalueof = function(row, col) {
        return meta_sheet.getRange(row, col).getValue();
    }
  
    // find the proper row containing column names
    var col_labels = 2;
    const column_label_of = function(row) {
        return metavalueof(row, col_labels);
    }
  
    var label_col_row = column_label_of(2)
    var first_row = column_label_of(3);
  
    const find_col_by_row_of_label = function(label_row) {
        var label = column_label_of(label_row).toString().toLowerCase();
        // assume max of 50 columns
        for (var i = 1; i < 50; i++) {
            var ref = valueof(label_col_row, i).toString().toLowerCase();
            if (ref == label) {
                console.log(label + " determined to be in column " + i);
                return i;
            }
        }
        console.log("Could not find column of label " + label)
        return undefined;
    }
  
    // meta values now
    // var category = metavalueof(2, 3); // Inferred automatically client-side
    // var subcategory = metavalueof(2, 4);
    // subcategory is now the sheet name
    var subcategory = sheet.getName();
    var difficulty = metavalueof(2, 5);
    if (difficulty != "ANY" || difficulty != "MYTHIC" || difficulty != "HEROIC") {
      difficulty = "ANY";
    }
    var duration = 3;
    
  
    // assign labels
  
    var col_name = find_col_by_row_of_label(4);
    var col_who = find_col_by_row_of_label(5);
    var col_message = find_col_by_row_of_label(6);
    var col_delay = find_col_by_row_of_label(7);
    var col_sound = find_col_by_row_of_label(8);
    var col_trigger = find_col_by_row_of_label(9);
    var col_event = find_col_by_row_of_label(10);
    var col_only_load_phase_num = find_col_by_row_of_label(11);    
    var col_bw_phase = find_col_by_row_of_label(12);
    var col_bw_bar_text = find_col_by_row_of_label(13);
    var col_bw_bar_before = find_col_by_row_of_label(14);
    var col_event_source = find_col_by_row_of_label(15);
    var col_event_target = find_col_by_row_of_label(16);
    var col_event_spell = find_col_by_row_of_label(17);
    var col_event_hp_unit = find_col_by_row_of_label(18);
    var col_event_hp = find_col_by_row_of_label(19);
    var col_send_aura = find_col_by_row_of_label(20);
    var col_repeat = find_col_by_row_of_label(21);
    var col_repeat_number = find_col_by_row_of_label(22);
    var col_repeat_offset = find_col_by_row_of_label(23);
    var col_repeat_mod = find_col_by_row_of_label(24);
    var col_stacks_operator = find_col_by_row_of_label(26);
    var col_stacks_number = find_col_by_row_of_label(27);
  
    var col_export_output = column_label_of(31);
    
    // var col_enabled = column_label_of(3);
    // var col_adjuster = column_label_of(10);
    // var col_difficulty = column_label_of(13);
    // var col_only_load_phase = column_label_of(16);
    // var col_bw_bar_check_text = column_label_of(19);
    // var col_bw_bar_check_spell = column_label_of(21);
    // var col_bw_bar_spell = column_label_of(22);
    // var col_event_check_source = column_label_of(24);
    // var col_event_check_target = column_label_of(25);
    // var col_event_check_spell = column_label_of(26);
    // var col_send_aura_check = column_label_of(32);
    // var col_check_stacks = column_label_of(40);
  
    console.log("First reminder found on row " + first_row);
    
    for (var i = first_row; i < 100; i++) {
        // closure
        const colvalue = function(col, defaul) {
            if (defaul == undefined) {
                defaul = "";
            }
            if (col == undefined) {
              throw new Error("Column names don't match");
            }
            var val = valueof(i, col);
            if (val == "") {
                return defaul;
            }
            return val;
        }
        // closure end
      // check for empty message
      if (colvalue(col_message) == "") {
          continue;
      }
  
      if (colvalue(col_name) != "") {
        names.push(colvalue(col_name));
        names.sort();
        for (var k = 0; k < names.length - 1; k++) {
          if (names[k] == names[k+1]) {
            //throw new Error("Duplicate names detected, this is not ideal..");
            exported = ["DUPLICATE NAMES"];
            break;
          }
        }
        var reminder = new Object();
        
        reminder.delay = new Object();
        reminder.trigger_opt = new Object();
        reminder.notification = new Object();
        reminder.notification.color = new Object();
        reminder.repeats = new Object();
  
        var who = colvalue(col_who);
        // if "who" is undef or empty, this is disabled
        var enabled = true;
        if (who == "" || who == undefined) {
          enabled = false;
        }
        if (who != "everyone" && who != "self") {
          who = "specific";
        }
  
        reminder.name = colvalue(col_name).toString();
        reminder.enabled = enabled;
        // reminder.category = category;
        reminder.subcategory = subcategory;
        reminder.trigger = colvalue(col_trigger);
        reminder.delay.delay_sec = parseFloat(colvalue(col_delay, 0));
        reminder.trigger_opt.difficulty = difficulty;
        reminder.notification.who = who;
        reminder.notification.message = colvalue(col_message);
        reminder.notification.sound = colvalue(col_sound, "None");
        reminder.notification.duration = parseFloat(duration);
        reminder.notification.specific_list = colvalue(col_who);
        reminder.notification.aura_to_check = colvalue(col_send_aura);
        reminder.notification.check_for_aura = reminder.notification.aura_to_check != "";
  
  
        reminder.trigger_opt.bw_phase = colvalue(col_bw_phase, 0);
        reminder.trigger_opt.bw_bar_before = parseFloat(colvalue(col_bw_bar_before));
        reminder.trigger_opt.bw_bar_text = colvalue(col_bw_bar_text);
        reminder.trigger_opt.bw_bar_check_text = reminder.trigger_opt.bw_bar_text != "";
        reminder.trigger_opt.only_load_phase_num = colvalue(col_only_load_phase_num);
        reminder.trigger_opt.only_load_phase = reminder.trigger_opt.only_load_phase_num != "";
        // reminder.trigger_opt.bw_bar_spellid = colvalue(col_bw_bar_spell);
        reminder.trigger_opt.bw_bar_check_spellid = false; // colvalue(col_bw_bar_check_spell, false);
  
        reminder.trigger_opt.event = colvalue(col_event);
        reminder.trigger_opt.source_name = colvalue(col_event_source);
        reminder.trigger_opt.dest_name = colvalue(col_event_target);
        reminder.trigger_opt.name = colvalue(col_event_spell);
        reminder.trigger_opt.boss_hp_unit = colvalue(col_event_hp_unit);
        reminder.trigger_opt.boss_hp_pct = parseFloat(colvalue(col_event_hp));
        reminder.trigger_opt.check_source = reminder.trigger_opt.source_name != ""; //colvalue(col_event_check_source, false);
        reminder.trigger_opt.check_dest = reminder.trigger_opt.dest_name != ""; //colvalue(col_event_check_target, false);
        reminder.trigger_opt.check_name = reminder.trigger_opt.name != ""; //colvalue(col_event_check_spell, false);
        
        reminder.trigger_opt.stacks_op = colvalue(col_stacks_operator);
        reminder.trigger_opt.stacks_count = parseFloat(colvalue(col_stacks_number));
        reminder.trigger_opt.check_stacks = reminder.trigger_opt.stacks_op != ""; // colvalue(col_check_stacks, false);
        
        console.log("Repeat for " + reminder.name + " = " +colvalue(col_repeat));
        reminder.repeats.setup = colvalue(col_repeat, "every_time");
        reminder.repeats.number = parseFloat(colvalue(col_repeat_number));
        reminder.repeats.offset = parseFloat(colvalue(col_repeat_offset));
        reminder.repeats.modulo = parseFloat(colvalue(col_repeat_mod));
  
        // i dont think this is even accessible from gui, just set it to true
        reminder.notification.send = true;
        
        reminder.notification.color[1] = 1;
        reminder.notification.color[2] = 1;
        reminder.notification.color[3] = 1;
        reminder.notification.color[4] = 1;
        
        exported.push(serialize_reminder(reminder));
        
      }
    }
    var strrepr = exported.join("§");
    console.log("Full size", strrepr.length);
    var deflated = deflate(strrepr); // RawDeflate.deflate
    console.log("Deflated size", deflated.length);
    var deflatedstr = to_libdeflate_printable(deflated);
    console.log("B64 size", deflatedstr.length);
    sheet.getRange(1, col_export_output).setValue(deflatedstr);
  }
  
  
  function deflate(input) {
    return pako.deflate(input);
  }
  
  function deflate_len(input) {
    var deflated = deflate(input);
    return deflated.length;
  }
  
  function deflate_try(input) {
    return to_libdeflate_printable(deflate(input));
  }
  
  var _byte_to_6bit_char = [
      "a", "b", "c", "d", "e", "f", "g", "h",
      "i", "j", "k", "l", "m", "n", "o", "p",
      "q", "r", "s", "t", "u", "v", "w", "x",
      "y", "z", "A", "B", "C", "D", "E", "F",
      "G", "H", "I", "J", "K", "L", "M", "N",
      "O", "P", "Q", "R", "S", "T", "U", "V",
      "W", "X", "Y", "Z", "0", "1", "2", "3",
      "4", "5", "6", "7", "8", "9", "(", ")",
  ]
  
  function string_byte_1(str, start) {
      // var char = str.charCodeAt(start);
    return str[start];
  }
  
  
  function to_libdeflate_printable(input) {
    // input = stringToBytes(input);
      var strlen = input.length;
      var strlenMinus2 = strlen - 2;
      var i = 0;
      var buffer = [];
      var buffer_size = 0
      while (i < strlenMinus2) {
      var x1 = string_byte_1(input, i); 
      var x2 = string_byte_1(input, i + 1); 
      var x3 = string_byte_1(input, i + 2);
          i = i + 3
          var cache = x1+x2*256+x3*65536
          var b1 = cache % 64
          cache = (cache - b1) / 64
          var b2 = cache % 64
          cache = (cache - b2) / 64
          var b3 = cache % 64
          var b4 = (cache - b3) / 64
          buffer_size = buffer_size + 1
          buffer[buffer_size] = _byte_to_6bit_char[b1] + _byte_to_6bit_char[b2] + _byte_to_6bit_char[b3] + _byte_to_6bit_char[b4]
    }
  
      var cache2 = 0;
      var cache_bitlen = 0;
      while (i < strlen) {
          var x = string_byte_1(input, i)
          cache2 = cache2 + x * Math.pow(2, cache_bitlen)
          cache_bitlen = cache_bitlen + 8
          i = i + 1
      }
  
      while (cache_bitlen > 0) {
          var bit6 = cache2 % 64
          buffer_size = buffer_size + 1
          buffer[buffer_size] = _byte_to_6bit_char[bit6]
          cache2 = (cache2 - bit6) / 64
          cache_bitlen = cache_bitlen - 6
      }
  
      return buffer.join("");
  }
  
  function showDialog() {  
    var html = HtmlService.createHtmlOutputFromFile('multiselectdialog').setSandboxMode(HtmlService.SandboxMode.IFRAME);
    SpreadsheetApp.getUi()
    .showSidebar(html);
  }
  function getValidationData(){
    //Browser.msgBox(test, Browser.Buttons.OK_CANCEL);
    try {
      var sheet = SpreadsheetApp.openById('1Y_LTfxDU9dxmiIlW8koRThaBxLA7tQ23m2EE-m1fmHQ');
      var tab = sheet.getSheetByName('Raid Info');
      var range = tab.getRange('C1');
      var players = range.getDataValidation().getCriteriaValues()[0].getValues();
      return players;
    } catch(e) {
      return null
    }
  }
  
  function setValues_(e, update) {
    var selectedValues = [];
    
    for (var i in e) {
      selectedValues.push(i);
    }
    var separator = ','
    var total = selectedValues.length
    if (total > 0) {
      var range = SpreadsheetApp.getActiveRange()
      var value = selectedValues.join(separator)
      if (update) {
        var values = range.getValues()
        // check every cell in range
        for (var row = 0; row < values.length; ++row) {
          for (var column = 0; column < values[row].length; ++column) {
            var currentValues = values[row][column].split(separator);//typeof values[row][column] === Array ? values[row][column].split(separator) : [values[row][column]+'']
            // find same values and remove them
            var newValues = []
            for (var j = 0; j < currentValues.length; ++j) {
              var uniqueValue = true
              for(var i = 0; i < total; ++i) {
                if (selectedValues[i] == currentValues[j]) {
                  uniqueValue = false
                  break
                }
              }
              
              if (uniqueValue && currentValues[j].trim() != '') {
                newValues.push(currentValues[j])
              }
            }
            
            if (newValues.length > 0) {
              range.getCell(row+1, column+1).setValue(newValues.join(separator)+separator+value)
            } else {
              range.getCell(row+1, column+1).setValue(value);
            }
          }
        }
      } else {
        range.setValue(value);
      }
    }
  }
  
  function updateCell(e) {
    return setValues_(e, true)
  }
  
  function fillCell(e) {
    setValues_(e)
  }
  
  function clearCell() {
    //Browser.msgBox('check2', Browser.Buttons.OK_CANCEL); 
    SpreadsheetApp.getActiveRange().setValue('');
  }
  
  
  
  
  
  
  
  
  
  
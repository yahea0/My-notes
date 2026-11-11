package com.yahea0.mynotes;

import android.app.Dialog;
import android.content.SharedPreferences;
import android.os.Bundle;
import android.view.View;
import android.view.Window;
import android.widget.ArrayAdapter;
import android.widget.Button;
import android.widget.EditText;
import android.widget.ListView;
import android.widget.TextView;
import android.widget.Toast;

import androidx.appcompat.app.AppCompatActivity;

import org.json.JSONArray;
import org.json.JSONObject;

import java.util.ArrayList;

public class MainActivity extends AppCompatActivity {

    private ListView listViewNotes;
    private EditText etSearch;
    private Button fabAdd, btnCalculator;
    private ArrayList<NoteModel> notesList = new ArrayList<>();
    private ArrayAdapter<String> adapter;
    private ArrayList<String> displayList = new ArrayList<>();
    private SharedPreferences sharedPreferences;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        listViewNotes = findViewById(R.id.listViewNotes);
        etSearch = findViewById(R.id.etSearch);
        fabAdd = findViewById(R.id.fabAdd);
        btnCalculator = findViewById(R.id.btnCalculator);

        sharedPreferences = getSharedPreferences("MyNotesPrefs", MODE_PRIVATE);
        loadNotes();

        adapter = new ArrayAdapter<>(this, android.R.layout.simple_list_item_1, displayList);
        listViewNotes.setAdapter(adapter);

        fabAdd.setOnClickListener(v -> openNoteEditor(null, -1));
        
        btnCalculator.setOnClickListener(v -> showCalculatorDialog());

        listViewNotes.setOnItemClickListener((parent, view, position, id) -> {
            if (position >= 0 && position < notesList.size()) {
                NoteModel selectedNote = notesList.get(position);
                openNoteEditor(selectedNote, position);
            }
        });
    }

    private void loadNotes() {
        notesList.clear();
        displayList.clear();
        String jsonStr = sharedPreferences.getString("notes_json", "[]");
        try {
            JSONArray jsonArray = new JSONArray(jsonStr);
            for (int i = 0; i < jsonArray.length(); i++) {
                JSONObject obj = jsonArray.getJSONObject(i);
                NoteModel note = new NoteModel(obj.getString("title"), obj.getString("content"));
                notesList.add(note);
                displayList.add(note.title + "\n" + note.content);
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    private void saveNotesToPrefs() {
        try {
            JSONArray jsonArray = new JSONArray();
            for (NoteModel note : notesList) {
                JSONObject obj = new JSONObject();
                obj.put("title", note.title);
                obj.put("content", note.content);
                jsonArray.put(obj);
            }
            sharedPreferences.edit().putString("notes_json", jsonArray.toString()).apply();
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    private void openNoteEditor(NoteModel note, int index) {
        Dialog dialog = new Dialog(this, android.R.style.Theme_Black_NoTitleBar_Fullscreen);
        dialog.requestWindowFeature(Window.FEATURE_NO_TITLE);
        dialog.setContentView(R.layout.dialog_note_editor);

        TextView tvTitle = dialog.findViewById(R.id.tvEditorTitle);
        EditText etTitle = dialog.findViewById(R.id.etNoteTitle);
        EditText etContent = dialog.findViewById(R.id.etNoteContent);
        Button btnSave = dialog.findViewById(R.id.btnSaveNote);
        Button btnDelete = dialog.findViewById(R.id.btnDeleteNote);

        if (note != null) {
            tvTitle.setText("تعديل الملاحظة");
            etTitle.setText(note.title);
            etContent.setText(note.content);
            btnDelete.setVisibility(View.VISIBLE);
        } else {
            tvTitle.setText("ملاحظة جديدة");
            btnDelete.setVisibility(View.GONE);
        }

        btnSave.setOnClickListener(v -> {
            String titleText = etTitle.getText().toString().trim();
            String contentText = etContent.getText().toString().trim();

            if (titleText.isEmpty() && contentText.isEmpty()) {
                dialog.dismiss();
                return;
            }

            if (index == -1) {
                notesList.add(0, new NoteModel(titleText, contentText));
            } else {
                notesList.set(index, new NoteModel(titleText, contentText));
            }

            saveNotesToPrefs();
            loadNotes();
            adapter.notifyDataSetChanged();
            dialog.dismiss();
        });

        btnDelete.setOnClickListener(v -> {
            if (index != -1) {
                notesList.remove(index);
                saveNotesToPrefs();
                loadNotes();
                adapter.notifyDataSetChanged();
            }
            dialog.dismiss();
        });

        dialog.show();
    }

    private void showCalculatorDialog() {
        Toast.makeText(this, "الآلة الحاسبة الذكية قيد التشغيل", Toast.LENGTH_SHORT).show();
    }

    public static class NoteModel {
        public String title;
        public String content;

        public NoteModel(String title, String content) {
            this.title = title;
            this.content = content;
        }
    }
}

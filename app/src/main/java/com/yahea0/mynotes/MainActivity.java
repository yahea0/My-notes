package com.yahea0.mynotes;

import android.app.Dialog;
import android.content.SharedPreferences;
import android.os.Bundle;
import android.text.Editable;
import android.text.TextWatcher;
import android.view.View;
import android.view.Window;
import android.widget.ArrayAdapter;
import android.widget.Button;
import android.widget.EditText;
import android.widget.ImageButton;
import android.widget.Spinner;
import android.widget.TextView;
import android.widget.Toast;

import androidx.appcompat.app.AppCompatActivity;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;

import com.google.android.material.floatingactionbutton.FloatingActionButton;

import org.json.JSONArray;
import org.json.JSONObject;

import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.List;
import java.util.Locale;

public class MainActivity extends AppCompatActivity {

    private RecyclerView recyclerViewNotes;
    private EditText etSearch;
    private FloatingActionButton fabAdd;
    private ImageButton btnCalculator;
    private TextView tabAll, tabGeneral, tabWork, tabStudy;
    
    private List<NoteModel> notesList = new ArrayList<>();
    private List<NoteModel> filteredList = new ArrayList<>();
    private NoteAdapter adapter;
    private SharedPreferences sharedPreferences;
    private String currentCategory = "الكل";

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        recyclerViewNotes = findViewById(R.id.recyclerViewNotes);
        etSearch = findViewById(R.id.etSearch);
        fabAdd = findViewById(R.id.fabAdd);
        btnCalculator = findViewById(R.id.btnCalculator);
        
        tabAll = findViewById(R.id.tabAll);
        tabGeneral = findViewById(R.id.tabGeneral);
        tabWork = findViewById(R.id.tabWork);
        tabStudy = findViewById(R.id.tabStudy);

        sharedPreferences = getSharedPreferences("MyNotesPrefs", MODE_PRIVATE);
        loadNotes();

        recyclerViewNotes.setLayoutManager(new LinearLayoutManager(this));
        adapter = new NoteAdapter(filteredList, note -> openNoteEditor(note));
        recyclerViewNotes.setAdapter(adapter);

        fabAdd.setOnClickListener(v -> openNoteEditor(null));
        btnCalculator.setOnClickListener(v -> Toast.makeText(this, "الآلة الحاسبة الذكية", Toast.LENGTH_SHORT).show());

        setupTabs();
        setupSearch();
        filterNotes();
    }

    private void setupTabs() {
        View.OnClickListener tabListener = v -> {
            tabAll.setBackgroundResource(R.drawable.bg_chip_normal);
            tabAll.setTextColor(getResources().getColor(android.R.color.darker_gray));
            tabGeneral.setBackgroundResource(R.drawable.bg_chip_normal);
            tabGeneral.setTextColor(getResources().getColor(android.R.color.darker_gray));
            tabWork.setBackgroundResource(R.drawable.bg_chip_normal);
            tabWork.setTextColor(getResources().getColor(android.R.color.darker_gray));
            tabStudy.setBackgroundResource(R.drawable.bg_chip_normal);
            tabStudy.setTextColor(getResources().getColor(android.R.color.darker_gray));

            TextView tv = (TextView) v;
            tv.setBackgroundResource(R.drawable.bg_chip_active);
            tv.setTextColor(getResources().getColor(android.R.color.black));
            currentCategory = tv.getText().toString();
            filterNotes();
        };

        tabAll.setOnClickListener(tabListener);
        tabGeneral.setOnClickListener(tabListener);
        tabWork.setOnClickListener(tabListener);
        tabStudy.setOnClickListener(tabListener);
    }

    private void setupSearch() {
        etSearch.addTextChangedListener(new TextWatcher() {
            @Override public void beforeTextChanged(CharSequence s, int start, int count, int after) {}
            @Override public void onTextChanged(CharSequence s, int start, int before, int count) { filterNotes(); }
            @Override public void afterTextChanged(Editable s) {}
        });
    }

    private void filterNotes() {
        filteredList.clear();
        String query = etSearch.getText().toString().toLowerCase().trim();

        for (NoteModel note : notesList) {
            boolean matchesCategory = currentCategory.equals("الكل") || note.category.equals(currentCategory);
            boolean matchesSearch = note.title.toLowerCase().contains(query) || note.content.toLowerCase().contains(query);
            if (matchesCategory && matchesSearch) {
                filteredList.add(note);
            }
        }
        adapter.notifyDataSetChanged();
    }

    private void loadNotes() {
        notesList.clear();
        String jsonStr = sharedPreferences.getString("notes_json", "[]");
        try {
            JSONArray arr = new JSONArray(jsonStr);
            for (int i = 0; i < arr.length(); i++) {
                JSONObject obj = arr.getJSONObject(i);
                notesList.add(new NoteModel(
                    obj.getLong("id"),
                    obj.getString("title"),
                    obj.getString("content"),
                    obj.getString("category"),
                    obj.getString("date")
                ));
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    private void saveNotes() {
        try {
            JSONArray arr = new JSONArray();
            for (NoteModel note : notesList) {
                JSONObject obj = new JSONObject();
                obj.put("id", note.id);
                obj.put("title", note.title);
                obj.put("content", note.content);
                obj.put("category", note.category);
                obj.put("date", note.date);
                arr.put(obj);
            }
            sharedPreferences.edit().putString("notes_json", arr.toString()).apply();
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    private void openNoteEditor(NoteModel note) {
        Dialog dialog = new Dialog(this, android.R.style.Theme_Black_NoTitleBar_Fullscreen);
        dialog.requestWindowFeature(Window.FEATURE_NO_TITLE);
        dialog.setContentView(R.layout.dialog_note_editor);

        TextView tvTitle = dialog.findViewById(R.id.tvEditorTitle);
        EditText etTitle = dialog.findViewById(R.id.etNoteTitle);
        EditText etContent = dialog.findViewById(R.id.etNoteContent);
        Spinner spinner = dialog.findViewById(R.id.spinnerCategory);
        ImageButton btnClose = dialog.findViewById(R.id.btnCloseEditor);
        ImageButton btnSave = dialog.findViewById(R.id.btnSaveNote);
        Button btnDelete = dialog.findViewById(R.id.btnDeleteNote);

        String[] categories = {"العام", "العمل", "الدراسة"};
        ArrayAdapter<String> spinnerAdapter = new ArrayAdapter<>(this, android.R.layout.simple_spinner_dropdown_item, categories);
        spinner.setAdapter(spinnerAdapter);

        if (note != null) {
            tvTitle.setText("تعديل الملاحظة");
            etTitle.setText(note.title);
            etContent.setText(note.content);
            for (int i = 0; i < categories.length; i++) {
                if (categories[i].equals(note.category)) {
                    spinner.setSelection(i);
                    break;
                }
            }
            btnDelete.setVisibility(View.VISIBLE);
        } else {
            tvTitle.setText("ملاحظة جديدة");
            btnDelete.setVisibility(View.GONE);
        }

        btnClose.setOnClickListener(v -> dialog.dismiss());

        btnSave.setOnClickListener(v -> {
            String title = etTitle.getText().toString().trim();
            String content = etContent.getText().toString().trim();
            String category = spinner.getSelectedItem().toString();
            String date = new SimpleDateFormat("yyyy/MM/dd", Locale.getDefault()).format(new Date());

            if (title.isEmpty() && content.isEmpty()) {
                dialog.dismiss();
                return;
            }

            if (note != null) {
                note.title = title;
                note.content = content;
                note.category = category;
            } else {
                notesList.add(0, new NoteModel(System.currentTimeMillis(), title, content, category, date));
            }

            saveNotes();
            filterNotes();
            dialog.dismiss();
        });

        btnDelete.setOnClickListener(v -> {
            if (note != null) {
                notesList.remove(note);
                saveNotes();
                filterNotes();
            }
            dialog.dismiss();
        });

        dialog.show();
    }
}

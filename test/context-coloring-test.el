(defconst context-coloring-test-path
  (file-name-directory (or load-file-name buffer-file-name)))

(defun context-coloring-test-resolve-path (path)
  (expand-file-name path context-coloring-test-path))

(defun get-string-from-file (path)
  (with-temp-buffer
    (insert-file-contents path)
    (buffer-string)))

(defun context-coloring-test-read-file (path)
  (get-string-from-file (context-coloring-test-resolve-path path)))

(defmacro context-coloring-test-with-fixture (fixture &rest body)
  "Evaluate BODY in a temporary buffer with the relative
FIXTURE."
  `(with-temp-buffer
     (insert (context-coloring-test-read-file ,fixture))
     ,@body))

(defun context-coloring-test-region-level-p (start end level)
  (let ((i 0)
        (length (- end start)))
    (while (< i length)
      (let ((point (+ i start)))
        (should (equal (get-text-property point 'face)
                       (intern-soft (concat "context-coloring-level-"
                                            (number-to-string level)
                                            "-face")))))
      (setq i (+ i 1)))))

(defun context-coloring-test-message-should-be (expected)
  (with-current-buffer "*Messages*"
    (let ((messages (split-string (buffer-substring-no-properties (point-min) (point-max)) "\n")))
      (let ((message (car (nthcdr (- (length messages) 2) messages))))
        (should (equal message expected))))))

(ert-deftest context-coloring-test-unsupported-mode ()
  (context-coloring-test-with-fixture
   "./fixtures/function-scopes.js"

   (context-coloring-mode)
   (context-coloring-test-message-should-be
    "Context coloring is not available for this major mode")))

(ert-deftest context-coloring-test-function-scopes ()
  (context-coloring-test-with-fixture
   "./fixtures/function-scopes.js"

   (js-mode)
   (context-coloring-mode)

   (sleep-for .25) ; Wait for asynchronous coloring to complete.

   (context-coloring-test-region-level-p 1 9 0)
   (context-coloring-test-region-level-p 9 23 1)
   (context-coloring-test-region-level-p 23 25 0)
   (context-coloring-test-region-level-p 25 34 1)
   (context-coloring-test-region-level-p 34 35 0)
   (context-coloring-test-region-level-p 35 52 1)
   (context-coloring-test-region-level-p 52 66 2)
   (context-coloring-test-region-level-p 66 72 1)
   (context-coloring-test-region-level-p 72 81 2)
   (context-coloring-test-region-level-p 81 82 1)
   (context-coloring-test-region-level-p 82 87 2)
   (context-coloring-test-region-level-p 87 89 1)))

(provide 'context-coloring-test)
